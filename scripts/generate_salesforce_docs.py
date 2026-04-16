#!/usr/bin/env python3
"""
Generate Salesforce org documentation from force-app/main/default metadata.
Uses only the Python standard library.

Optional: place `metadata_api_types.txt` next to this script (one Metadata API type name per line).
Generate it from a tab-separated coverage matrix with:

    python3 scripts/parse_coverage_matrix.py < your_matrix.txt

Heuristic summaries use naming patterns aligned with the Metadata API coverage matrix (Settings, Rule,
Definition, etc.). For authoritative behavior, see Salesforce Metadata API Reference.

After generating docs/, optional enrichment in Cursor: prefer @docs over force-app alone; see
docs/CURSOR_WORKFLOW.md.
"""
from __future__ import annotations

import html
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

NS = "{http://soap.sforce.com/2006/04/metadata}"

_SCRIPT_DIR = Path(__file__).resolve().parent
_METADATA_API_TYPE_REGISTRY: frozenset[str] | None = None


def load_metadata_api_type_registry() -> frozenset[str]:
    """Optional list of type names (e.g. from Metadata API coverage matrix). Empty if file missing."""
    global _METADATA_API_TYPE_REGISTRY
    if _METADATA_API_TYPE_REGISTRY is not None:
        return _METADATA_API_TYPE_REGISTRY
    path = _SCRIPT_DIR / "metadata_api_types.txt"
    if not path.is_file():
        _METADATA_API_TYPE_REGISTRY = frozenset()
        return _METADATA_API_TYPE_REGISTRY
    names: set[str] = set()
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            names.add(line)
    _METADATA_API_TYPE_REGISTRY = frozenset(names)
    return _METADATA_API_TYPE_REGISTRY


def heuristic_metadata_type_description(tag: str) -> str | None:
    """
    When METADATA_TYPE_PURPOSE has no entry, infer what this Metadata API type represents from its name.
    Covers patterns common in the official coverage matrix (Settings, Rule, Definition, etc.).
    """
    t = tag
    if t.endswith("Settings"):
        return (
            f"**{t}** is **feature or product settings** metadata. It stores org-wide configuration for a specific "
            f"Salesforce capability (often under **Setup**). Deploying this file changes defaults or toggles for that feature."
        )
    if t.endswith("Rule") and not t.endswith("WorkflowRule"):
        return (
            f"**{t}** is a **rule** metadata component: it expresses conditions and outcomes (validation, duplicate detection, "
            f"moderation, etc.) that the platform evaluates at runtime."
        )
    if t in ("AssignmentRules", "AutoResponseRules", "EscalationRules", "MatchingRules", "SharingRules", "Workflow"):
        return (
            f"**{t}** is a **container** for multiple rules of that category (e.g. lead/case assignment, auto-response, escalation). "
            f"Deploying it updates the corresponding automation package in the org."
        )
    if t.endswith("Rules"):
        return (
            f"**{t}** groups **automation or enforcement rules** that Salesforce evaluates in order. "
            f"It is deployable metadata that changes routing, matching, or escalation behavior."
        )
    if t.endswith("Definition") or t.endswith("Def"):
        return (
            f"**{t}** is a **definition** object: it describes structure, scoring, AI models, orchestration, or similar "
            f"configuration that other features reference by API name."
        )
    if t.endswith("Template"):
        return (
            f"**{t}** is a **template** used to create or format records, emails, documents, or processes from a reusable pattern."
        )
    if t.endswith("Config") or t.endswith("Configuration"):
        return (
            f"**{t}** is **configuration** metadata: it parameterizes a product feature (industries, insurance, scheduling, etc.) "
            f"without storing transactional data."
        )
    if t.endswith("Bundle"):
        return (
            f"**{t}** is a **bundle** of related assets (UI, OmniStudio, Analytics, GenAI, etc.) deployed as a single unit."
        )
    if t.endswith("Process") and t != "EntitlementProcess":
        return (
            f"**{t}** defines a **business process** (steps, stages, or automation) used by Salesforce features that reference it."
        )
    if t == "EntitlementProcess":
        return (
            "**EntitlementProcess** defines milestones and exit criteria for **Service Cloud entitlements** on cases."
        )
    if t.endswith("Extension"):
        return (
            f"**{t}** extends a standard or managed capability with **additional fields, behavior, or UI** for a specific product area."
        )
    if t.endswith("Component"):
        return (
            f"**{t}** is a **reusable UI or application component** (console, app sidebar, Lightning, etc.) referenced by apps or pages."
        )
    if t.endswith("Application") and t != "ExternalClientApplication":
        return (
            f"**{t}** defines a **Salesforce application** (tabs, branding, navigation) users launch from the App Launcher."
        )
    if t == "ExternalClientApplication":
        return (
            "**ExternalClientApplication** configures **external OAuth/mobile clients** that connect to Salesforce APIs."
        )
    if t.endswith("Page") and t.startswith("Apex"):
        return (
            f"**{t}** is a **Visualforce page** (server-rendered UI) backed by Apex controllers and optional extensions."
        )
    if t == "ApexClass":
        return None  # explicit in METADATA_TYPE_PURPOSE
    if t.endswith("Class") and "Apex" not in t and not t.startswith("Lightning"):
        return (
            f"**{t}** is a **class-like metadata** definition (not necessarily Apex), used by the feature that owns this type."
        )
    if t.endswith("Trigger"):
        return (
            f"**{t}** is **Apex trigger** metadata: code that runs on DML for a specified sObject."
        )
    if t.endswith("WorkflowRule"):
        return (
            "**WorkflowRule** is **classic workflow** criteria and immediate/time-dependent actions (being superseded by Flow in many orgs)."
        )
    if t.endswith("Workflow") and t != "WorkflowRule":
        return (
            f"**{t}** is part of **classic Workflow** (alerts, field updates, outbound messages, tasks)."
        )
    if t.endswith("Site") or t == "CustomSite":
        return (
            f"**{t}** configures **public or authenticated sites** (Visualforce/Lightning on a force.com domain)."
        )
    if t == "Network" or t.endswith("Community"):
        return (
            f"**{t}** configures **Experience Cloud** (communities): branding, login, and member experience."
        )
    if t.endswith("Dashboard") or t.startswith("Wave") and "Dashboard" in t:
        return (
            f"**{t}** is an **analytics dashboard** definition (components, filters, datasets)."
        )
    if t.endswith("Report") and "Workflow" not in t:
        return (
            f"**{t}** is a **report** definition (columns, filters, bucketing) in Salesforce reporting."
        )
    if t.endswith("ReportType"):
        return (
            f"**{t}** defines a **custom report type** (joinable objects and fields available to reports)."
        )
    if t.endswith("Folder"):
        return (
            f"**{t}** is a **folder** for organizing reports, dashboards, documents, or email templates with sharing."
        )
    if t in ("Group", "Queue", "Role", "Territory", "Territory2", "Territory2Model", "Territory2Rule", "Territory2Type"):
        return (
            f"**{t}** is **org structure** metadata (queues, public groups, roles, or territories) used in sharing and assignment."
        )
    if "Sharing" in t and t.endswith("Rule"):
        return (
            f"**{t}** widens **record access** beyond organization-wide defaults for specific groups or criteria."
        )
    if t.endswith("PermissionSet") or t == "MutingPermissionSet" or t == "PortalDelegablePermissionSet":
        return (
            f"**{t}** grants **additive permissions** (objects, fields, classes, apps) to users without replacing their profile."
        )
    if t == "Profile":
        return None
    if t.endswith("Policy") and "Transaction" in t:
        return (
            "**TransactionSecurityPolicy** defines **real-time transaction security** policies (event-based blocking/monitoring)."
        )
    if t.endswith("Policy"):
        return (
            f"**{t}** is a **policy** definition (security, mobile, OAuth, push, etc.) for connected experiences."
        )
    if t.endswith("Certificate") or t.endswith("Certificates"):
        return (
            f"**{t}** stores **certificate or key material** references for TLS, signing, or identity integrations."
        )
    if t.endswith("Credential") or t == "NamedCredential":
        return None
    if t.endswith("DataSource") or t.endswith("Connector") or "DataConnector" in t:
        return (
            f"**{t}** connects Salesforce to **external or internal data** (CDC, S3, ingest APIs, etc.)."
        )
    if t.endswith("Translation") or t == "Translations":
        return (
            f"**{t}** holds **translated labels** for UI, reports, or metadata in multiple languages."
        )
    if t.endswith("ValueSet") or t == "StandardValue" or t == "PicklistValue":
        return (
            f"**{t}** defines **picklist values** (global or standard) and labels for fields."
        )
    if t.endswith("Metadata") and t != "CustomMetadata":
        return (
            f"**{t}** is **metadata packaging** for deployable configuration records or types."
        )
    if t.endswith("Labels") or t == "CustomLabels":
        return (
            f"**{t}** stores **custom label** key/value pairs for translation and reuse in code and UI."
        )
    if t.endswith("Permission") and "Set" not in t:
        return (
            f"**{t}** defines a **custom permission** boolean checked in Apex, Flows, and validation for feature toggles."
        )
    if t.endswith("Layout") and "Compact" not in t and "Flexi" not in t:
        return (
            f"**{t}** is a **page layout** (sections, related lists, buttons) for a given object and record type context."
        )
    if t == "FlexiPage":
        return None
    if t.endswith("CompactLayout"):
        return (
            f"**{t}** defines **compact layout** fields for record highlights and mobile headers."
        )
    if t.endswith("ListView"):
        return (
            f"**{t}** defines a **list view** (filters, columns) for an object tab."
        )
    if t.endswith("RecordType"):
        return (
            f"**{t}** defines a **record type** (picklists, layouts, business process) for a segment of records on one object."
        )
    if t.endswith("Tab"):
        return (
            f"**{t}** defines a **custom tab** in the Salesforce navigation (object, web tab, or Lightning component)."
        )
    if t.endswith("WebLink"):
        return (
            f"**{t}** is a **custom link or button** that opens a URL or executes actions from a record page."
        )
    if t.endswith("StaticResource"):
        return (
            f"**{t}** packages **static assets** (JS, CSS, ZIP, images) for Visualforce and Lightning."
        )
    if t.endswith("EmailTemplate"):
        return (
            f"**{t}** is an **email template** (HTML/text) with merge fields for outbound messaging."
        )
    if t.endswith("Letterhead"):
        return (
            f"**{t}** defines **email letterhead** styling for classic HTML emails."
        )
    if t.endswith("Document") and "Category" not in t:
        return (
            f"**{t}** is a **library document** in classic Documents for attachments and templates."
        )
    if t.endswith("ContentAsset"):
        return (
            f"**{t}** is a **content asset** for images and branding in Lightning and Experience Builder."
        )
    if t.endswith("Flow") or t == "FlowTest" or t == "FlowCategory":
        return (
            f"**{t}** relates to **Flow** automation (tests, categories, or legacy flow metadata)."
        )
    if t.endswith("Bot") or t.startswith("Bot"):
        return (
            f"**{t}** is **Einstein Bot / conversational** metadata (dialogs, versions, templates)."
        )
    if t.startswith("Omni"):
        return (
            f"**{t}** is **OmniStudio** metadata (scripts, integrations, cards, tracking)."
        )
    if t.startswith("GenAi") or t.startswith("AI") or "Einstein" in t or t.startswith("Ai"):
        return (
            f"**{t}** is **AI / Einstein / GenAI** configuration (prompts, agents, scoring, surfaces)."
        )
    if t.startswith("Industries") or t.startswith("Care") or t.startswith("Ins"):
        return (
            f"**{t}** is **Industry Cloud** (Health, Financial Services, Insurance, etc.) configuration."
        )
    if t.endswith("Wave") or t.startswith("Wave") or t.startswith("Analytics"):
        return (
            f"**{t}** is **CRM Analytics / Tableau** (formerly Wave) metadata: apps, datasets, lenses, recipes."
        )
    if t.endswith("ManagedContent") or t.startswith("DigitalExperience") or t == "ExperienceBundle":
        return (
            f"**{t}** is **Experience Cloud / CMS** content or digital experience packaging."
        )
    if t.endswith("Index") or t == "CustomIndex":
        return (
            f"**{t}** defines a **custom database index** for selective queries on large objects."
        )
    if t.endswith("InstalledPackage"):
        return (
            "**InstalledPackage** records a **managed package** version installed in the org."
        )
    if t.endswith("FeatureParameter"):
        return (
            f"**{t}** is a **feature management / LMO** parameter for managed packages (boolean, int, date)."
        )
    return None


def local_name(tag: str) -> str:
    if "}" in tag:
        return tag.split("}", 1)[1]
    return tag


def text_escape_md(s: str | None) -> str:
    if s is None:
        return ""
    s = str(s).replace("\n", " ").replace("\r", "")
    s = s.replace("|", "\\|")
    return s


def md_cell(val: Any) -> str:
    if val is None or val == "":
        return "—"
    return text_escape_md(val)


def mermaid_id(name: str, prefix: str) -> str:
    safe = re.sub(r"[^a-zA-Z0-9_]", "_", name)
    if not safe or not safe[0].isalpha() and safe[0] != "_":
        safe = "n_" + safe
    return f"{prefix}_{safe}"[:200]


def mermaid_label(s: str) -> str:
    s = str(s).replace('"', "'")[:120]
    return s


def child_text(el: ET.Element | None, tag: str) -> str | None:
    if el is None:
        return None
    c = el.find(f"{NS}{tag}")
    if c is not None and c.text:
        return c.text.strip()
    return None


def child_bool(el: ET.Element | None, tag: str) -> bool | None:
    t = child_text(el, tag)
    if t is None:
        return None
    return t.lower() == "true"


def parse_xml(path: Path) -> ET.Element:
    tree = ET.parse(path)
    return tree.getroot()


# --- Discovery (all top-level metadata folders) ---

BINARY_SUFFIXES = frozenset(
    {
        ".png",
        ".jpg",
        ".jpeg",
        ".gif",
        ".webp",
        ".ico",
        ".woff",
        ".woff2",
        ".ttf",
        ".eot",
        ".pdf",
        ".zip",
        ".jar",
        ".class",
        ".map",
        ".svg",
    }
)

SKIP_DIR_NAMES = frozenset({"node_modules", ".git", "__pycache__", ".svn"})


def path_has_skip_dir(p: Path) -> bool:
    return any(part in SKIP_DIR_NAMES for part in p.parts)


@dataclass(frozen=True)
class ComponentInfo:
    """One documentable unit within a metadata folder."""

    comp_id: str
    path: Path
    kind: str  # flow, object, cls, trigger, lwc, aura, xml, text, other
    display_name: str


def doc_id_from_rel(rel: Path) -> str:
    s = str(rel).replace("\\", "/").replace("/", "__")
    s = re.sub(r"[^a-zA-Z0-9_\-\.]+", "_", s)
    if not s:
        s = "unnamed"
    if s[0].isdigit():
        s = "n_" + s
    return s[:220]


def human_title(folder_name: str) -> str:
    known = {
        "flows": "Flows",
        "objects": "Objects",
        "classes": "Apex Classes",
        "triggers": "Apex Triggers",
        "lwc": "Lightning Web Components",
        "aura": "Aura Components",
        "namedCredentials": "Named Credentials",
        "externalCredentials": "External Credentials",
        "customMetadata": "Custom Metadata",
        "staticresources": "Static Resources",
        "permissionsets": "Permission Sets",
        "profiles": "Profiles",
        "labels": "Custom Labels",
        "remoteSiteSettings": "Remote Site Settings",
        "cspTrustedSites": "CSP Trusted Sites",
        "duplicateRules": "Duplicate Rules",
        "matchingRules": "Matching Rules",
        "assignmentRules": "Assignment Rules",
        "escalationRules": "Escalation Rules",
        "autoResponseRules": "Auto-Response Rules",
        "pathAssistants": "Path Assistants",
        "applications": "Applications",
        "tabs": "Custom Tabs",
        "flexipages": "FlexiPages",
        "layouts": "Layouts",
        "compactLayouts": "Compact Layouts",
        "contentassets": "Content Assets",
        "digitalExperiences": "Digital Experiences",
        "experiences": "Experiences",
        "sites": "Sites",
        "networks": "Networks",
        "communities": "Communities",
        "email": "Email Templates",
        "letterhead": "Letterheads",
        "reportTypes": "Report Types",
        "dashboards": "Dashboards",
        "reports": "Reports",
        "documents": "Documents",
        "weblinks": "Web Links",
        "quickActions": "Quick Actions",
        "globalValueSets": "Global Value Sets",
        "standardValueSets": "Standard Value Sets",
        "customPermissions": "Custom Permissions",
        "groups": "Groups",
        "queues": "Queues",
        "roles": "Roles",
        "sharingRules": "Sharing Rules",
        "settings": "Settings",
    }
    return known.get(folder_name, folder_name.replace("_", " ").title())


def list_components(folder: Path) -> list[ComponentInfo]:
    """Enumerate documentable components for any Salesforce metadata folder."""
    n = folder.name
    out: list[ComponentInfo] = []

    if n == "flows":
        for p in sorted(folder.glob("*.flow-meta.xml")):
            api = p.name.replace(".flow-meta.xml", "")
            out.append(ComponentInfo(api, p, "flow", api))
        return out

    if n == "objects":
        for d in sorted(folder.iterdir()):
            if d.is_dir() and (d / f"{d.name}.object-meta.xml").exists():
                out.append(ComponentInfo(d.name, d, "object", d.name))
        return out

    if n == "classes":
        for p in sorted(folder.glob("*.cls")):
            out.append(ComponentInfo(p.stem, p, "cls", p.stem))
        return out

    if n == "triggers":
        for p in sorted(folder.glob("*.trigger")):
            out.append(ComponentInfo(p.stem, p, "trigger", p.stem))
        return out

    if n == "lwc":
        for d in sorted(folder.iterdir()):
            if d.is_dir() and not path_has_skip_dir(d):
                if list(d.glob("*.js-meta.xml")):
                    out.append(ComponentInfo(d.name, d, "lwc", d.name))
        return out

    if n == "aura":
        for d in sorted(folder.iterdir()):
            if d.is_dir() and not path_has_skip_dir(d):
                out.append(ComponentInfo(d.name, d, "aura", d.name))
        return out

    # Generic: all *-meta.xml (recursive), skip junk paths
    metas: list[Path] = []
    for p in sorted(folder.glob("**/*-meta.xml")):
        if not p.is_file() or path_has_skip_dir(p):
            continue
        metas.append(p)
    if not metas:
        for p in sorted(folder.glob("**/*.xml")):
            if not p.is_file() or path_has_skip_dir(p):
                continue
            metas.append(p)

    if metas:
        for p in metas:
            rel = p.relative_to(folder)
            cid = doc_id_from_rel(rel)
            out.append(ComponentInfo(cid, p, "xml", str(rel).replace("\\", "/")))
        return out

    # Last resort: non-binary files (e.g. Markdown archives, JSON, plain text)
    for p in sorted(folder.rglob("*")):
        if not p.is_file() or path_has_skip_dir(p):
            continue
        if p.suffix.lower() in BINARY_SUFFIXES:
            continue
        rel = p.relative_to(folder)
        cid = doc_id_from_rel(rel)
        suf = p.suffix.lower()
        kind = "text" if suf in (".md", ".txt", ".json", ".csv", ".css", ".scss") else "other"
        out.append(ComponentInfo(cid, p, kind, str(rel).replace("\\", "/")))

    return out


def discover_chapters(force_default: Path) -> list[tuple[str, int, str]]:
    """Return list of (folder_name, component_count, human_title) for every non-empty metadata folder."""
    chapters: list[tuple[str, int, str]] = []
    if not force_default.is_dir():
        return chapters

    for child in sorted(force_default.iterdir()):
        if not child.is_dir() or child.name.startswith("."):
            continue
        comps = list_components(child)
        if not comps:
            continue
        chapters.append((child.name, len(comps), human_title(child.name)))

    return chapters


# --- Generic metadata documentation ---

# Short Salesforce product explanations by Metadata API root element name (for Summary paragraphs).
METADATA_TYPE_PURPOSE: dict[str, str] = {
    "NamedCredential": (
        "A **Named Credential** is a named connection definition Salesforce uses for **secure outbound HTTP callouts** "
        "(from Apex `HttpRequest`, Flows, External Services, Einstein, etc.) to external APIs. Instead of hard-coding URLs "
        "and secrets in code, integrations reference this component by **label/API name**. It typically stores the **endpoint URL**, "
        "whether **merge fields** are allowed in headers/body, whether an **Authorization header** is auto-generated, and links to "
        "an **External Credential** (or other auth model) for OAuth/API keys. **Callout status** controls whether callouts using "
        "this definition are allowed."
    ),
    "ExternalCredential": (
        "**External Credential** holds **authentication material and handshake settings** (OAuth, JWT, API keys, certificates) "
        "that Named Credentials and other features use. It does not usually store the API URL by itself—that is often on the "
        "Named Credential—while this component defines **how** Salesforce authenticates to the external system."
    ),
    "RemoteSiteSetting": (
        "**Remote Site Settings** allow-list external **HTTP/HTTPS endpoints** that Salesforce can call out to, working with "
        "security rules for org-wide callouts (legacy patterns; Named Credentials are preferred for new integrations)."
    ),
    "CspTrustedSite": (
        "**CSP Trusted Sites** declare origins allowed for **Content Security Policy** in Lightning and web contexts, reducing XSS risk."
    ),
    "ConnectedApp": (
        "**Connected App** defines an OAuth integration entry point: client id/secret, callback URLs, scopes, and policies for "
        "external apps accessing Salesforce APIs."
    ),
    "CustomMetadata": (
        "**Custom Metadata** stores configurable application data as deployable metadata (types and records), often used for "
        "feature flags, routing tables, and environment-specific configuration without custom objects."
    ),
    "CustomLabel": (
        "**Custom Labels** store user-facing strings for translation and reuse in Apex, Visualforce, and Lightning."
    ),
    "DuplicateRule": (
        "**Duplicate Rules** evaluate records against matching rules and define **actions** (block, alert) when duplicates are detected."
    ),
    "MatchingRule": (
        "**Matching Rules** define how Salesforce compares field values to detect **duplicate** records."
    ),
    "Profile": (
        "**Profile** defines baseline **object CRUD, field-level security, tab visibility, app settings, and login IP** for users assigned to it."
    ),
    "PermissionSet": (
        "**Permission Set** grants **additional** permissions (objects, fields, apps, system permissions) without replacing the user profile."
    ),
    "PermissionSetGroup": (
        "**Permission Set Group** bundles multiple permission sets for easier assignment."
    ),
    "Flow": (
        "**Flow** (in a generic metadata file) represents automation definition; in source format, record-triggered and autolaunched "
        "flows are usually under `flows/` as separate files."
    ),
    "ApexClass": (
        "**Apex Class** metadata describes server-side Java-like code: business logic, integrations, and services running on the Salesforce platform."
    ),
    "ApexTrigger": (
        "**Apex Trigger** runs before/after insert, update, delete on a specified **sObject**."
    ),
    "LightningComponentBundle": (
        "**Aura / Lightning bundle** metadata describes a Lightning component package (markup, controller, helper, design)."
    ),
    "CustomObject": (
        "**Custom Object** defines a new database table in Salesforce with fields, relationships, and behavior."
    ),
    "CustomField": (
        "**Custom Field** extends a standard or custom object with additional columns and field-level metadata."
    ),
    "ValidationRule": (
        "**Validation Rule** blocks record saves when a **formula** evaluates to true, with a user-facing error message."
    ),
    "WorkflowRule": (
        "**Workflow Rule** (classic automation) runs when criteria match; often paired with field updates, alerts, or tasks."
    ),
    "AssignmentRules": (
        "**Assignment Rules** route **Leads** or **Cases** to queues/users based on criteria."
    ),
    "AutoResponseRules": (
        "**Auto-Response Rules** send automatic email responses when inbound cases/leads match conditions."
    ),
    "EscalationRules": (
        "**Escalation Rules** reassign or escalate **Cases** over time when criteria are met."
    ),
    "ApprovalProcess": (
        "**Approval Process** defines multi-step **record approvals** with approvers, criteria, and actions."
    ),
    "EmailTemplate": (
        "**Email Template** defines HTML/text emails with merge fields for outbound messaging."
    ),
    "Report": (
        "**Report** metadata describes analytics report definition (columns, filters, format)."
    ),
    "Dashboard": (
        "**Dashboard** metadata describes visual dashboards composed of report components."
    ),
    "FlexiPage": (
        "**Lightning Page (FlexiPage)** defines Lightning **App / Record / Home** page layouts and component placement."
    ),
    "Layout": (
        "**Page Layout** controls field sections, related lists, and buttons on classic and Lightning record pages (where applicable)."
    ),
    "CompactLayout": (
        "**Compact Layout** defines the highlighted fields shown in record headers and mobile highlights."
    ),
    "ListView": (
        "**List View** defines filtered, column-ordered lists for an object tab."
    ),
    "RecordType": (
        "**Record Type** offers different picklists, page layouts, and business processes per segment of the same object."
    ),
    "CustomTab": (
        "**Custom Tab** exposes an object, web tab, or Lightning component in the app navigation."
    ),
    "CustomApplication": (
        "**Custom Application** defines a Lightning app: branding, navigation items, and utility bar."
    ),
    "StaticResource": (
        "**Static Resource** packages JS, CSS, images, or ZIP archives for Visualforce and Lightning."
    ),
    "Document": (
        "**Document** (in Documents tab) stores files for classic integrations and email templates."
    ),
    "ContentAsset": (
        "**Content Asset** deploys images/assets referenced in Lightning and Experience Builder."
    ),
    "Queue": (
        "**Queue** is a holding bucket for records (often Cases or Leads) assigned to a group."
    ),
    "Group": (
        "**Public Group** collects users and roles for **sharing rules** and access."
    ),
    "Role": (
        "**Role** participates in the **role hierarchy** for record sharing and reporting."
    ),
    "Territory2": (
        "**Territory** (Territory Management 2) models sales territories for account assignment and forecasting."
    ),
    "SharingRules": (
        "**Sharing Rules** widen access beyond OWD for roles, public groups, or territories."
    ),
    "CustomSite": (
        "**Site** exposes Visualforce or Lightning on a branded public URL with guest user access controls."
    ),
    "Network": (
        "**Experience Cloud Site (Network)** configures community login, branding, and member experience."
    ),
}


def metadata_purpose_paragraph(root_tag: str) -> str:
    """Return a general Salesforce explanation for this metadata root element, or a generic fallback."""
    if root_tag in METADATA_TYPE_PURPOSE:
        return METADATA_TYPE_PURPOSE[root_tag]
    h = heuristic_metadata_type_description(root_tag)
    if h:
        return h
    return (
        f"This file is **{root_tag}** metadata: a deployable configuration component in the Salesforce Metadata API. "
        f"It affects how the org behaves at runtime when features that reference this component are used. "
        f"See the property tables below for the exact values deployed from source."
    )


def xml_leaf_path_values(el: ET.Element, prefix: str = "") -> list[tuple[str, str]]:
    """Collect (dotted_path, text) for every element that has direct text and no element children, or leaf nodes."""
    tag = local_name(el.tag)
    path = f"{prefix}.{tag}" if prefix else tag
    children = list(el)
    rows: list[tuple[str, str]] = []
    if not children:
        t = (el.text or "").strip()
        if t:
            rows.append((path, t))
        return rows
    for ch in children:
        rows.extend(xml_leaf_path_values(ch, path))
    return rows


def xml_direct_simple_children(root: ET.Element) -> list[tuple[str, str]]:
    """Only immediate children with simple text (no nested elements)."""
    rows: list[tuple[str, str]] = []
    for ch in root:
        ln = local_name(ch.tag)
        if not list(ch):
            t = (ch.text or "").strip()
            if t:
                rows.append((ln, t))
    return rows


def xml_repeating_groups_table(root: ET.Element, group_tag: str) -> str:
    """Render sibling groups (e.g. customConfigurationParameters) as a markdown table."""
    groups = [el for el in root if local_name(el.tag) == group_tag]
    if not groups:
        return ""
    # Collect all distinct child tag names
    keys: set[str] = set()
    group_dicts: list[dict[str, str]] = []
    for g in groups:
        d: dict[str, str] = {}
        for ch in g:
            k = local_name(ch.tag)
            keys.add(k)
            t = (ch.text or "").strip()
            if t:
                d[k] = t
        if d:
            group_dicts.append(d)
    if not group_dicts:
        return ""
    cols = sorted(keys)
    lines = [f"### `{group_tag}` (repeating)", "", "| " + " | ".join(cols) + " |", "|" + "|".join(["---"] * len(cols)) + "|"]
    for d in group_dicts:
        lines.append("| " + " | ".join(text_escape_md(d.get(c, "—")) for c in cols) + " |")
    lines.append("")
    return "\n".join(lines)


def narrative_for_named_credential(root: ET.Element) -> str:
    """Detailed English summary specific to NamedCredential XML."""
    label = child_text(root, "label") or "this named credential"
    nct = child_text(root, "namedCredentialType") or "—"
    cs = child_text(root, "calloutStatus") or "—"
    amb = child_text(root, "allowMergeFieldsInBody")
    amh = child_text(root, "allowMergeFieldsInHeader")
    gah = child_text(root, "generateAuthorizationHeader")

    url = ext = None
    pairs = xml_leaf_path_values(root)
    # Scan customConfigurationParameters blocks (namespaced)
    for g in root.findall(f".//{NS}customConfigurationParameters"):
        pn = pt = pv = None
        for ch in g:
            t = local_name(ch.tag)
            v = (ch.text or "").strip()
            if t == "parameterName":
                pn = v
            elif t == "parameterType":
                pt = v
            elif t == "parameterValue":
                pv = v
        if pn and pv:
            pl = pn.lower()
            tl = (pt or "").lower()
            if pl in ("url", "endpoint") or tl == "url":
                url = pv
            if pl == "externalcredential" or tl == "authentication":
                ext = pv

    # Fallback: any parameterValue that looks like URL
    if not url:
        for _path, val in pairs:
            if val.startswith("http://") or val.startswith("https://"):
                url = val
                break
    if not ext:
        ec = child_text(root, "externalCredential")
        if ec:
            ext = ec
    if not ext:
        for _path, val in pairs:
            if val and not val.startswith("http") and "External" in val and len(val) < 120:
                if _path.endswith("parameterValue") and "Credential" in val:
                    ext = val
                    break

    sentences: list[str] = []
    sentences.append(
        f"The org defines a **Named Credential** named **{text_escape_md(label)}** so that declarative and programmatic "
        f"integrations can call an external HTTP endpoint **without embedding secrets in code**."
    )
    sentences.append(
        f"It is configured as **`{text_escape_md(nct)}`**, with **callout status `{text_escape_md(cs)}`**, meaning "
        f"callouts that reference this named credential are **{'allowed' if str(cs).lower() == 'enabled' else 'controlled per status'}**."
    )
    if url:
        sentences.append(
            f"The **target endpoint** for the integration is **`{text_escape_md(url)}`** (often the base URL for OAuth or API calls)."
        )
    if ext:
        sentences.append(
            f"Authentication details are delegated to **External Credential** **`{text_escape_md(ext)}`**, so secrets, "
            f"OAuth tokens, or signing keys stay in that component while this named credential references it."
        )
    sentences.append(
        f"**Merge fields** in HTTP body are **{'allowed' if str(amb).lower() == 'true' else 'not allowed'}**; "
        f"in headers **{'allowed' if str(amh).lower() == 'true' else 'not allowed'}**. "
        f"The platform **{'will' if str(gah).lower() == 'true' else 'may not'}** auto-generate an **Authorization** header "
        f"when the auth model requires it."
    )
    sentences.append(
        "Downstream, **Flows, Apex, OmniStudio, or integration features** that reference this named credential by API name "
        "will use these settings for every outbound request unless overridden."
    )
    return " ".join(sentences)


def narrative_for_xml_root(root: ET.Element, ci: ComponentInfo) -> str:
    """Multi-sentence Summary section: purpose + type-specific narrative when implemented."""
    tag = local_name(root.tag)
    base = metadata_purpose_paragraph(tag)
    reg = load_metadata_api_type_registry()
    reg_note = ""
    if reg and tag in reg:
        reg_note = (
            "\n\n*This root element **`" + text_escape_md(tag) + "`** appears in your Metadata API coverage registry "
            "(`scripts/metadata_api_types.txt`), i.e. it is a type Salesforce documents for retrieve/deploy scope.*"
        )
    if tag == "NamedCredential":
        specific = narrative_for_named_credential(root)
        return f"{specific}\n\n*{base}*{reg_note}"
    # Generic detailed summary from first-level fields
    simple = xml_direct_simple_children(root)
    if not simple:
        leaves = xml_leaf_path_values(root)[:40]
        simple = [(p.split(".")[-1], v) for p, v in leaves]
    highlights: list[str] = []
    for k, v in simple[:25]:
        if len(v) > 200:
            v = v[:197] + "..."
        highlights.append(f"**{k}** = `{text_escape_md(v)}`")
    detail = (
        f"In this deployment file, the key settings include: {', '.join(highlights[:12])}."
        if highlights
        else "Inspect the property tables below for all values extracted from XML."
    )
    return f"{detail}\n\n{base}{reg_note}"


def xml_dependencies_section(root: ET.Element, root_tag: str) -> str:
    """Best-effort dependency bullets from common reference fields."""
    deps: list[str] = []
    pairs = xml_leaf_path_values(root)
    for path, val in pairs:
        low = path.lower()
        if any(
            x in low
            for x in (
                "externalcredential",
                "namedcredential",
                "flow",
                "apexclass",
                "permission",
                "profile",
                "role",
                "queue",
            )
        ):
            if val and len(val) < 200:
                deps.append(f"- **{path}:** `{text_escape_md(val)}`")
    # Dedupe preserve order
    seen: set[str] = set()
    uniq: list[str] = []
    for d in deps:
        if d not in seen:
            seen.add(d)
            uniq.append(d)
    if not uniq:
        return (
            "- *(No common reference fields detected automatically; search the property table for API names of related metadata.)*"
        )
    return "\n".join(uniq[:40])


def render_xml_file_doc(ci: ComponentInfo) -> str:
    try:
        root = parse_xml(ci.path)
    except Exception as e:
        return f"# {ci.display_name}\n\n**Error parsing XML:** {e}\n"
    tag = local_name(root.tag)
    summary_body = narrative_for_xml_root(root, ci)

    # Tables: simple direct children
    simple_rows = xml_direct_simple_children(root)
    table_lines = [
        "### All simple (leaf) properties",
        "",
        "| Property | Value |",
        "|----------|-------|",
    ]
    for k, v in simple_rows:
        if len(v) > 500:
            v = v[:497] + "..."
        table_lines.append(f"| `{text_escape_md(k)}` | {text_escape_md(v)} |")
    if len(simple_rows) == 0:
        table_lines.append("| — | *(no direct leaf children; see nested table below)* |")

    # Full leaf paths for nested metadata
    leaves = xml_leaf_path_values(root)
    nested_lines = [
        "",
        "### All values (including nested paths)",
        "",
        "| Path | Value |",
        "|------|-------|",
    ]
    for path, val in leaves[:200]:
        if len(val) > 400:
            val = val[:397] + "..."
        nested_lines.append(f"| `{text_escape_md(path)}` | {text_escape_md(val)} |")
    if len(leaves) > 200:
        nested_lines.append(f"| … | *({len(leaves) - 200} more rows omitted)* |")

    repeating = ""
    for gtag in ("customConfigurationParameters", "parameters", "property", "scope", "urls"):
        block = xml_repeating_groups_table(root, gtag)
        if block:
            repeating += block + "\n"

    dep_section = xml_dependencies_section(root, tag)

    lines = [
        f"# {ci.display_name}",
        "",
        f"**Type:** {tag} (Metadata) | **Path:** `{ci.path.name}` | **Kind:** {ci.kind}",
        "",
        "---",
        "",
        "## Summary",
        "",
        summary_body,
        "",
        "---",
        "",
        "## Technical Details",
        "",
        *table_lines,
        "",
        *nested_lines,
        "",
        repeating,
        "---",
        "",
        "## Dependencies",
        "",
        dep_section,
        "",
        "---",
        "",
    ]
    return "\n".join(lines)


APEX_DECL = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|private|protected|global|webservice)\s+)+(?:abstract\s+)?(?:static\s+)?(?:override\s+)?(?:[\w\.<>,\[\]\s]+\s+)?(\w+)\s*\(",
    re.MULTILINE,
)


def summarize_xml_element(root: ET.Element, max_elements: int = 120) -> str:
    lines: list[str] = []
    tag = local_name(root.tag)
    lines.append(f"- **Root element:** `{tag}`")
    count = 0
    for el in root.iter():
        if el is root:
            continue
        count += 1
        if count > max_elements:
            lines.append(f"- … *(truncated after {max_elements} child elements)*")
            break
        ln = local_name(el.tag)
        t = (el.text or "").strip()
        if len(t) > 120:
            t = t[:117] + "..."
        attrs = []
        for ak, av in (el.attrib or {}).items():
            if av:
                attrs.append(f"{ak}={av[:40]}")
        extra = f" ({', '.join(attrs)})" if attrs else ""
        if t or attrs:
            lines.append(f"  - `{ln}`{extra}" + (f": {text_escape_md(t)}" if t else ""))
    return "\n".join(lines)


def read_text_safe(path: Path, limit: int = 8000) -> str:
    try:
        t = path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        return f"*Could not read file: {e}*"
    if len(t) > limit:
        return t[:limit] + f"\n\n… *({len(t) - limit} more characters omitted)*"
    return t


def extract_apex_methods(source: str) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()
    for m in APEX_DECL.finditer(source):
        name = m.group(1)
        if name and name not in seen and not name.startswith("_"):
            seen.add(name)
            names.append(name)
    return sorted(names)


def extract_apex_file_header_comment(source: str) -> str | None:
    """
    Pull the leading Javadoc-style /** ... */ or consecutive // lines before the first class/interface/enum.
    Used to explain what the Apex code is for without running an LLM.
    """
    s = source.lstrip()
    if s.startswith("/**"):
        end = s.find("*/")
        if end != -1:
            body = s[3:end]
            lines = []
            for ln in body.splitlines():
                ln = re.sub(r"^\s*\*\s?", "", ln).strip()
                if ln:
                    lines.append(ln)
            text = " ".join(lines)
            return text[:4000] if text else None
    lines_top: list[str] = []
    for line in source.splitlines()[:80]:
        st = line.strip()
        if st.startswith("//"):
            lines_top.append(st[2:].strip())
        elif st.startswith("/*") and not st.startswith("/**"):
            break
        elif st and not st.startswith("//"):
            if lines_top:
                break
            if re.match(r"^(public|private|global|@|abstract|final)\s", st):
                break
    if lines_top:
        return " ".join(lines_top)[:4000]
    return None


def render_apex_class_doc(ci: ComponentInfo) -> str:
    src = read_text_safe(ci.path, 120_000)
    meta_path = Path(str(ci.path) + "-meta.xml")
    api_v = status = "—"
    if meta_path.is_file():
        try:
            mroot = parse_xml(meta_path)
            api_v = md_cell(child_text(mroot, "apiVersion"))
            status = md_cell(child_text(mroot, "status"))
        except Exception:
            pass
    methods = extract_apex_methods(src)
    meth_rows = "\n".join(f"| `{m}` | — | — | From source parse |" for m in methods[:200])
    if not methods:
        meth_rows = "| — | — | — | No method signatures detected by regex |"
    header_doc = extract_apex_file_header_comment(src)
    summary_core = (
        f"Apex class **`{ci.display_name}`** (`classes/{ci.path.name}`) is compiled and executed on the Salesforce server. "
        f"It typically implements **business logic, integrations, or shared services** invoked from triggers, flows, "
        f"REST endpoints, batch jobs, or tests. The table below lists **method names** inferred from signatures (not full signatures)."
    )
    if header_doc:
        summary_body = (
            f"{summary_core}\n\n**Author / description from source comment:** {text_escape_md(header_doc)}"
        )
    else:
        summary_body = (
            f"{summary_core}\n\n*No `/** ... */` or leading `//` block was found at the top of the file; add a class-level "
            f"comment in the Apex source for a richer summary on the next doc generation.*"
        )
    return "\n".join(
        [
            f"# {ci.display_name}",
            "",
            f"**Type:** Apex Class | **Status:** {status} | **API Version:** {api_v} | **Object/Trigger:** —",
            "",
            "---",
            "",
            "## Summary",
            "",
            summary_body,
            "",
            "---",
            "",
            "## Technical Details",
            "",
            "### Methods (heuristic)",
            "",
            "| Method Name | Access | Return Type | Description |",
            "|-------------|--------|-------------|-------------|",
            meth_rows,
            "",
            "### Source",
            "",
            "```apex",
            read_text_safe(ci.path, 15_000),
            "```",
            "",
            "---",
            "",
            "## Dependencies",
            "",
            "*(Review imports and type references in source above.)*",
            "",
            "---",
            "",
        ]
    )


def render_apex_trigger_doc(ci: ComponentInfo) -> str:
    src = read_text_safe(ci.path, 80_000)
    meta_path = Path(str(ci.path) + "-meta.xml")
    api_v = status = obj = "—"
    if meta_path.is_file():
        try:
            mroot = parse_xml(meta_path)
            api_v = md_cell(child_text(mroot, "apiVersion"))
            status = md_cell(child_text(mroot, "status"))
            obj = md_cell(child_text(mroot, "table"))
        except Exception:
            pass
    header_doc = extract_apex_file_header_comment(src)
    trig_sum = (
        f"This **Apex trigger** runs in the **{obj}** transaction pipeline (before/after insert, update, delete as coded). "
        f"It can **validate, enrich, or sync** records and may call other Apex or async work."
    )
    if header_doc:
        trig_sum += f"\n\n**Comment from source:** {text_escape_md(header_doc)}"
    return "\n".join(
        [
            f"# {ci.display_name}",
            "",
            f"**Type:** Apex Trigger | **Status:** {status} | **API Version:** {api_v} | **Object/Trigger:** {obj}",
            "",
            "---",
            "",
            "## Summary",
            "",
            trig_sum,
            "",
            "---",
            "",
            "## Technical Details",
            "",
            "### Source",
            "",
            "```apex",
            src,
            "```",
            "",
            "---",
            "",
            "## Dependencies",
            "",
            f"- **Object:** {obj}",
            "",
            "---",
            "",
        ]
    )


def render_lwc_bundle_doc(ci: ComponentInfo) -> str:
    d = ci.path
    files = sorted(d.rglob("*"))
    file_list = [f"- `{p.relative_to(d)}`" for p in files if p.is_file()][:80]
    meta_lines = ""
    for mp in sorted(d.glob("*.js-meta.xml")):
        try:
            root = parse_xml(mp)
            meta_lines = summarize_xml_element(root, 40)
        except Exception as e:
            meta_lines = f"*(parse error: {e})*"
        break
    return "\n".join(
        [
            f"# {ci.display_name}",
            "",
            "**Type:** Lightning Web Component bundle | **Status:** — | **API Version:** (see meta) | **Object/Trigger:** —",
            "",
            "---",
            "",
            "## Summary",
            "",
            f"LWC bundle `{ci.display_name}` under `lwc/`. Files listed below; `*.js-meta.xml` excerpt included.",
            "",
            "---",
            "",
            "## Technical Details",
            "",
            "### Files in bundle",
            "",
            "\n".join(file_list) if file_list else "- —",
            "",
            "### LightningComponentBundle meta (excerpt)",
            "",
            meta_lines or "—",
            "",
            "---",
            "",
            "## Dependencies",
            "",
            "*(Review HTML/JS imports and `import` statements in bundle files.)*",
            "",
            "---",
            "",
        ]
    )


def render_aura_bundle_doc(ci: ComponentInfo) -> str:
    d = ci.path
    files = sorted(d.rglob("*"))
    file_list = [f"- `{p.relative_to(d)}`" for p in files if p.is_file()][:100]
    return "\n".join(
        [
            f"# {ci.display_name}",
            "",
            "**Type:** Aura bundle | **Status:** — | **API Version:** — | **Object/Trigger:** —",
            "",
            "---",
            "",
            "## Summary",
            "",
            f"Aura bundle `{ci.display_name}` under `aura/`.",
            "",
            "---",
            "",
            "## Technical Details",
            "",
            "### Files in bundle",
            "",
            "\n".join(file_list) if file_list else "- —",
            "",
            "---",
            "",
            "## Dependencies",
            "",
            "*(Review `.cmp`, controllers, and helpers manually.)*",
            "",
            "---",
            "",
        ]
    )


def render_text_or_other_doc(ci: ComponentInfo) -> str:
    body = read_text_safe(ci.path, 12_000)
    return "\n".join(
        [
            f"# {ci.display_name}",
            "",
            f"**Type:** File ({ci.kind}) | **Path:** `{ci.path.name}`",
            "",
            "---",
            "",
            "## Summary",
            "",
            "Non-metadata or non-XML file included under this folder for documentation completeness.",
            "",
            "---",
            "",
            "## Content (excerpt)",
            "",
            "```",
            body,
            "```",
            "",
            "---",
            "",
        ]
    )


def render_generic_component_doc(ci: ComponentInfo) -> str:
    if ci.kind == "xml":
        return render_xml_file_doc(ci)
    if ci.kind == "cls":
        return render_apex_class_doc(ci)
    if ci.kind == "trigger":
        return render_apex_trigger_doc(ci)
    if ci.kind == "lwc":
        return render_lwc_bundle_doc(ci)
    if ci.kind == "aura":
        return render_aura_bundle_doc(ci)
    if ci.kind in ("text", "other"):
        return render_text_or_other_doc(ci)
    return render_xml_file_doc(ci)


def generic_inventory_mermaid(folder_name: str, display_names: list[str], max_nodes: int = 50) -> str:
    lines = ["graph TD", f'  root["{mermaid_label(folder_name)}"]']
    for i, dn in enumerate(display_names[:max_nodes]):
        nid = f"n{i}"
        lines.append(f'  {nid}["{mermaid_label(dn[:80])}"]')
        lines.append(f"  root --> {nid}")
    if len(display_names) > max_nodes:
        lines.append(f'  more["… +{len(display_names) - max_nodes} more"]')
        lines.append("  root --> more")
    return "```mermaid\n" + "\n".join(lines) + "\n```"


def write_generic_chapter(folder: Path, docs_sub: Path, chapter_title: str) -> None:
    """Generate README + one markdown per component for any non-flow/non-object folder."""
    comps = list_components(folder)
    if not comps:
        return
    docs_sub.mkdir(parents=True, exist_ok=True)
    # Ensure unique .md filenames
    seen_count: dict[str, int] = {}
    resolved: list[tuple[ComponentInfo, str]] = []
    for c in comps:
        base = c.comp_id
        n = seen_count.get(base, 0)
        seen_count[base] = n + 1
        fid = base if n == 0 else f"{base}__{n}"
        resolved.append((c, fid))

    names = [c.display_name for c, _ in resolved]
    readme = [
        f"# Chapter: {chapter_title}",
        "",
        "## Overview",
        "",
        f"This chapter documents **{len(comps)}** component(s) from `force-app/main/default/{folder.name}/`. "
        f"Salesforce metadata in this folder is summarized automatically; specialized relationship graphs are only extracted where parsers exist.",
        "",
        "## Architecture Diagram",
        "",
        "Inventory of components in this folder (each item is documented; links are not inferred between components unless stated in per-file docs):",
        "",
        generic_inventory_mermaid(folder.name, names),
        "",
        "## Component Index",
        "",
        "| # | Component Name | Type | Trigger/Object | Status |",
        "|---|---------------|------|----------------|--------|",
    ]
    for i, (c, fid) in enumerate(resolved, 1):
        type_col = c.kind
        readme.append(
            f"| {i} | [{text_escape_md(c.display_name)}](./{fid}.md) | {text_escape_md(type_col)} | — | — |"
        )
    readme.extend(["", "---", ""])
    (docs_sub / "README.md").write_text("\n".join(readme), encoding="utf-8")

    for c, fid in resolved:
        try:
            body = render_generic_component_doc(c)
        except Exception as e:
            body = f"# {c.display_name}\n\n**Error:** {e}\n"
        (docs_sub / f"{fid}.md").write_text(body, encoding="utf-8")


# --- Flow parsing ---

FLOW_CONNECTABLE = frozenset(
    {
        "actionCalls",
        "apexPluginCalls",
        "assignments",
        "collectionProcessors",
        "customErrors",
        "decisions",
        "loops",
        "orchestratedStages",
        "recordCreates",
        "recordDeletes",
        "recordLookups",
        "recordRollbacks",
        "recordUpdates",
        "screens",
        "subflows",
        "transforms",
        "waits",
    }
)


def iter_flow_elements(flow_root: ET.Element) -> list[ET.Element]:
    out: list[ET.Element] = []
    for child in flow_root:
        ln = local_name(child.tag)
        if ln in FLOW_CONNECTABLE or ln in ("start",):
            out.append(child)
    return out


def get_target_refs_from_connector(parent: ET.Element | None) -> str | None:
    if parent is None:
        return None
    tr = parent.find(f".//{NS}targetReference")
    if tr is not None and tr.text:
        return tr.text.strip()
    return None


def element_outgoing_edges(elem: ET.Element, elem_type: str) -> list[tuple[str, str]]:
    """Return list of (edge_label, target_api_name)."""
    edges: list[tuple[str, str]] = []
    ln = local_name(elem.tag)

    def add_conn(label: str, conn_el: ET.Element | None) -> None:
        if conn_el is None:
            return
        ref = get_target_refs_from_connector(conn_el)
        if ref:
            edges.append((label, ref))

    if ln == "start":
        conn = elem.find(f"{NS}connector")
        add_conn("start", conn)
        return edges

    if ln == "decisions":
        dc = elem.find(f"{NS}defaultConnector")
        dlab = child_text(elem, "defaultConnectorLabel") or "default"
        add_conn(dlab, dc)
        for rule in elem.findall(f"{NS}rules"):
            rlab = child_text(rule, "label") or child_text(rule, "name") or "rule"
            rc = rule.find(f"{NS}connector")
            add_conn(rlab, rc)
        return edges

    if ln == "loops":
        add_conn("next", elem.find(f"{NS}nextValueConnector"))
        add_conn("done", elem.find(f"{NS}noMoreValuesConnector"))
        return edges

    # default: single connector + optional fault
    add_conn("", elem.find(f"{NS}connector"))
    fc = elem.find(f"{NS}faultConnector")
    if fc is not None:
        add_conn("fault", fc)
    return edges


def flow_element_name(elem: ET.Element) -> str | None:
    n = child_text(elem, "name")
    return n


def parse_flow_file(path: Path) -> dict[str, Any]:
    root = parse_xml(path)
    api_version = child_text(root, "apiVersion")
    label = child_text(root, "label") or path.stem.replace(".flow-meta", "")
    description = child_text(root, "description")
    interview_label = child_text(root, "interviewLabel")
    process_type = child_text(root, "processType")
    status = child_text(root, "status")
    environments = child_text(root, "environments")

    start = root.find(f"{NS}start")
    trigger_object = None
    trigger_type = None
    record_trigger_type = None
    schedule = None
    start_filters: list[dict[str, Any]] = []
    if start is not None:
        trigger_object = child_text(start, "object")
        trigger_type = child_text(start, "triggerType")
        record_trigger_type = child_text(start, "recordTriggerType")
        sched = start.find(f"{NS}schedule")
        if sched is not None:
            schedule = ET.tostring(sched, encoding="unicode")[:500]
        for fl in start.findall(f"{NS}filters"):
            start_filters.append(
                {
                    "field": child_text(fl, "field"),
                    "operator": child_text(fl, "operator"),
                }
            )

    # Variables
    variables: list[dict[str, Any]] = []
    for v in root.findall(f"{NS}variables"):
        variables.append(
            {
                "name": child_text(v, "name"),
                "dataType": child_text(v, "dataType"),
                "isInput": child_bool(v, "isInput"),
                "isOutput": child_bool(v, "isOutput"),
                "isCollection": child_bool(v, "isCollection"),
                "default": child_text(v.find(f"{NS}value"), "stringValue")
                if v.find(f"{NS}value") is not None
                else None,
            }
        )

    # Decisions detail
    decisions_detail: list[dict[str, Any]] = []
    for d in root.findall(f"{NS}decisions"):
        rules_out: list[dict[str, Any]] = []
        for rule in d.findall(f"{NS}rules"):
            conds: list[dict[str, Any]] = []
            for c in rule.findall(f"{NS}conditions"):
                conds.append(
                    {
                        "left": child_text(c, "leftValueReference"),
                        "operator": child_text(c, "operator"),
                        "right": _condition_right_value(c),
                    }
                )
            rules_out.append(
                {
                    "name": child_text(rule, "name"),
                    "label": child_text(rule, "label"),
                    "conditionLogic": child_text(rule, "conditionLogic"),
                    "conditions": conds,
                    "connector": get_target_refs_from_connector(rule.find(f"{NS}connector")),
                }
            )
        decisions_detail.append(
            {
                "name": child_text(d, "name"),
                "label": child_text(d, "label"),
                "defaultConnector": get_target_refs_from_connector(d.find(f"{NS}defaultConnector")),
                "defaultConnectorLabel": child_text(d, "defaultConnectorLabel"),
                "rules": rules_out,
            }
        )

    def record_op_common(elem: ET.Element, kind: str) -> dict[str, Any]:
        obj = child_text(elem, "object")
        fault = get_target_refs_from_connector(elem.find(f"{NS}faultConnector"))
        filters: list[dict[str, Any]] = []
        for fl in elem.findall(f"{NS}filters"):
            filters.append(
                {
                    "field": child_text(fl, "field"),
                    "operator": child_text(fl, "operator"),
                }
            )
        assigns: list[dict[str, str | None]] = []
        for ia in elem.findall(f"{NS}inputAssignments"):
            assigns.append(
                {
                    "field": child_text(ia, "field"),
                    "value": _assignment_value_summary(ia),
                }
            )
        return {
            "kind": kind,
            "name": child_text(elem, "name"),
            "label": child_text(elem, "label"),
            "object": obj,
            "faultConnector": fault,
            "filterLogic": child_text(elem, "filterLogic"),
            "filters": filters,
            "inputAssignments": assigns,
            "inputReference": child_text(elem, "inputReference"),
            "getFirstRecordOnly": child_text(elem, "getFirstRecordOnly"),
        }

    record_lookups = [record_op_common(x, "lookup") for x in root.findall(f"{NS}recordLookups")]
    record_creates = [record_op_common(x, "create") for x in root.findall(f"{NS}recordCreates")]
    record_updates = [record_op_common(x, "update") for x in root.findall(f"{NS}recordUpdates")]
    record_deletes = [record_op_common(x, "delete") for x in root.findall(f"{NS}recordDeletes")]

    if trigger_object:
        for ro in record_updates:
            if not ro.get("object"):
                ro["object"] = trigger_object
        for ro in record_deletes:
            if not ro.get("object"):
                ro["object"] = trigger_object

    lookup_by_name = {x["name"]: x.get("object") for x in record_lookups if x.get("name")}
    for ro in record_updates + record_deletes:
        if ro.get("object"):
            continue
        ir = ro.get("inputReference")
        if ir and ir in lookup_by_name and lookup_by_name[ir]:
            ro["object"] = lookup_by_name[ir]

    action_calls: list[dict[str, Any]] = []
    for a in root.findall(f"{NS}actionCalls"):
        action_calls.append(
            {
                "name": child_text(a, "name"),
                "label": child_text(a, "label"),
                "actionName": child_text(a, "actionName"),
                "actionType": child_text(a, "actionType"),
                "faultConnector": get_target_refs_from_connector(a.find(f"{NS}faultConnector")),
            }
        )

    subflows: list[dict[str, Any]] = []
    for s in root.findall(f"{NS}subflows"):
        subflows.append(
            {
                "name": child_text(s, "name"),
                "label": child_text(s, "label"),
                "flowName": child_text(s, "flowName"),
                "faultConnector": get_target_refs_from_connector(s.find(f"{NS}faultConnector")),
            }
        )

    # Graph: nodes and edges for internal mermaid
    node_names: set[str] = set()
    edges: list[tuple[str, str, str]] = []  # from, to, label

    for elem in root.iter():
        if elem == root:
            continue
        ln = local_name(elem.tag)
        if ln in FLOW_CONNECTABLE or ln == "start":
            n = flow_element_name(elem)
            if n:
                node_names.add(n)

    for elem in root.iter():
        ln = local_name(elem.tag)
        if ln not in FLOW_CONNECTABLE and ln != "start":
            continue
        n = flow_element_name(elem)
        if not n:
            continue
        for elabel, tgt in element_outgoing_edges(elem, ln):
            if tgt:
                edges.append((n, tgt, elabel))

    start_el = root.find(f"{NS}start")
    if start_el is not None:
        sref = get_target_refs_from_connector(start_el.find(f"{NS}connector"))
        if sref:
            edges.insert(0, ("Start", sref, "start"))
            node_names.add("Start")

    # Other element types (listing)
    other_elements: dict[str, list[str]] = defaultdict(list)
    seen_other: set[tuple[str, str]] = set()
    for child in root:
        ln = local_name(child.tag)
        if ln in (
            "apiVersion",
            "description",
            "interviewLabel",
            "label",
            "processType",
            "status",
            "environments",
            "processMetadataValues",
            "runInMode",
            "areMetricsLoggedToDataCloud",
            "isAdditionalPermissionRequiredToRun",
            "timeZoneSidKey",
            "start",
        ):
            continue
        if ln in FLOW_CONNECTABLE or ln in (
            "variables",
            "formulas",
            "constants",
            "textTemplates",
            "choices",
            "dynamicChoiceSets",
            "recordLookups",
            "recordCreates",
            "recordUpdates",
            "recordDeletes",
            "actionCalls",
            "subflows",
            "decisions",
        ):
            continue
        for item in root.findall(f"{NS}{ln}"):
            nm = child_text(item, "name")
            if nm and (ln, nm) not in seen_other:
                seen_other.add((ln, nm))
                other_elements[ln].append(nm)

    flow_api_name = path.name.replace(".flow-meta.xml", "")

    # Dependencies
    deps_objects: set[str] = set()
    if trigger_object:
        deps_objects.add(trigger_object)
    for ro in record_lookups + record_creates + record_updates + record_deletes:
        o = ro.get("object")
        if o:
            deps_objects.add(o)
    deps_subflows = {s["flowName"] for s in subflows if s.get("flowName")}
    deps_apex = set()
    for a in action_calls:
        if (a.get("actionType") or "").lower() == "apex" and a.get("actionName"):
            deps_apex.add(a["actionName"])

    return {
        "path": path,
        "apiName": flow_api_name,
        "apiVersion": api_version,
        "label": label,
        "description": description,
        "interviewLabel": interview_label,
        "processType": process_type,
        "status": status,
        "environments": environments,
        "start": {
            "object": trigger_object,
            "triggerType": trigger_type,
            "recordTriggerType": record_trigger_type,
            "schedule": schedule,
            "filters": start_filters,
        },
        "variables": variables,
        "decisions": decisions_detail,
        "recordLookups": record_lookups,
        "recordCreates": record_creates,
        "recordUpdates": record_updates,
        "recordDeletes": record_deletes,
        "actionCalls": action_calls,
        "subflows": subflows,
        "graph": {"nodes": sorted(node_names), "edges": edges},
        "otherElements": dict(other_elements),
        "dependencies": {
            "objects": sorted(deps_objects),
            "subflows": sorted(deps_subflows),
            "apexActions": sorted(deps_apex),
        },
    }


def _condition_right_value(c: ET.Element) -> str:
    rv = c.find(f"{NS}rightValue")
    if rv is None:
        return ""
    for tag in ("stringValue", "booleanValue", "numberValue", "elementReference", "dateValue"):
        t = child_text(rv, tag)
        if t:
            return f"{tag}:{t}"
    return ""


def _assignment_value_summary(ia: ET.Element) -> str:
    v = ia.find(f"{NS}value")
    if v is None:
        return ""
    for tag in ("stringValue", "booleanValue", "numberValue", "elementReference"):
        t = child_text(v, tag)
        if t:
            return f"{tag}:{t[:80]}"
    return ""


def build_flow_chapter_graphs(all_flows: list[dict[str, Any]]) -> tuple[str, str]:
    """
    (1) Object-centric: which record-triggered flows connect to which objects.
    (2) Subflow dependency subgraph (only flows that call or are called).
    """
    flow_names = {f["apiName"] for f in all_flows}

    obj_to_flows: dict[str, list[str]] = defaultdict(list)
    sub_edges: list[tuple[str, str]] = []

    for f in all_flows:
        fn = f["apiName"]
        st = f.get("start") or {}
        obj = st.get("object")
        tt = st.get("triggerType") or ""
        if obj and "Record" in tt:
            obj_to_flows[obj].append(fn)

        for sf in f.get("subflows") or []:
            tgt = sf.get("flowName")
            if tgt:
                sub_edges.append((fn, tgt))

    # Diagram 1: objects + flows that trigger on them (declare nodes once)
    lines1 = ["graph LR"]
    all_objs = sorted(obj_to_flows.keys())
    all_flows_rt = sorted({f for flows in obj_to_flows.values() for f in flows if f in flow_names})
    for obj in all_objs:
        oid = mermaid_id(obj, "O")
        lines1.append(f'  {oid}["{mermaid_label(obj)}"]')
    for fl in all_flows_rt:
        fid = mermaid_id(fl, "F")
        lines1.append(f'  {fid}["{mermaid_label(fl)}"]')
    for obj, flows in sorted(obj_to_flows.items()):
        oid = mermaid_id(obj, "O")
        for fl in sorted(set(flows)):
            if fl not in flow_names:
                continue
            fid = mermaid_id(fl, "F")
            lines1.append(f"  {fid} -->|record-trigger| {oid}")
    if len(all_objs) == 0 and len(all_flows_rt) == 0:
        lines1.append('  empty["No record-triggered start objects found"]')

    # Diagram 2: subflow calls only
    lines2 = ["graph TD"]
    involved = set()
    for a, b in sub_edges:
        involved.add(a)
        involved.add(b)
    for name in sorted(involved):
        nid = mermaid_id(name, "SF")
        lines2.append(f'  {nid}["{mermaid_label(name)}"]')
    seen_e = set()
    for a, b in sub_edges:
        if a not in involved or b not in involved:
            continue
        key = (a, b)
        if key in seen_e:
            continue
        seen_e.add(key)
        aid = mermaid_id(a, "SF")
        bid = mermaid_id(b, "SF")
        lines2.append(f"  {aid} -->|subflow| {bid}")
    if len(lines2) == 1:
        lines2.append('  empty["No subflow references"]')

    # Object relationship diagram for six standard objects (from field metadata — filled later)
    return "\n".join(lines1), "\n".join(lines2)


def flow_summary_paragraph(data: dict[str, Any]) -> str:
    parts: list[str] = []
    label = data.get("label") or data.get("apiName")
    pt = data.get("processType") or "Unknown"
    st = data.get("start") or {}
    obj = st.get("object")
    tt = st.get("triggerType")
    rt = st.get("recordTriggerType")
    status = data.get("status") or "Unknown"

    if obj and tt:
        parts.append(
            f'The flow "{label}" ({pt}, status {status}) is configured with trigger type {tt}'
            + (f" for {rt} on {obj}" if rt else f" on {obj}")
            + "."
        )
    else:
        parts.append(
            f'The flow "{label}" is a {pt} flow (status {status}). '
            f"It does not use a record-triggered start element in metadata, or runs as screen/autolaunched/scheduled per its configuration."
        )

    desc = (data.get("description") or "").strip()
    if desc:
        parts.append(html.unescape(desc[:600]) + ("..." if len(desc) > 600 else ""))

    rc = len(data.get("recordCreates") or [])
    ru = len(data.get("recordUpdates") or [])
    rl = len(data.get("recordLookups") or [])
    rd = len(data.get("recordDeletes") or [])
    if rl or rc or ru or rd:
        parts.append(
            f" It performs {rl} record lookup(s), {rc} create(s), {ru} update(s), and {rd} delete(s) as defined in the flow metadata."
        )

    subs = data.get("subflows") or []
    if subs:
        names = ", ".join(s["flowName"] for s in subs if s.get("flowName"))
        parts.append(f" It invokes the following subflow(s): {names}.")

    acts = data.get("actionCalls") or []
    if acts:
        an = ", ".join(
            f'{a.get("actionName")} ({a.get("actionType") or "action"})' for a in acts if a.get("actionName")
        )
        parts.append(f" Actions invoked include: {an}.")

    decs = data.get("decisions") or []
    if decs:
        parts.append(f" The automation includes {len(decs)} decision element(s) that branch execution based on configured conditions.")

    return " ".join(parts)


def render_internal_flow_mermaid(data: dict[str, Any]) -> str:
    edges = data["graph"]["edges"]
    if not edges:
        return "```mermaid\ngraph TD\n  empty[\"No connector graph extracted\"]\n```"

    nodes: set[str] = set()
    for a, b, _ in edges:
        nodes.add(a)
        nodes.add(b)

    lines = ["graph TD"]
    for n in sorted(nodes):
        nid = mermaid_id(n, "E")
        lines.append(f'  {nid}["{mermaid_label(n)}"]')

    seen: set[tuple[str, str, str]] = set()
    for a, b, lbl in edges:
        if not lbl:
            lbl = "next"
        key = (a, b, lbl)
        if key in seen:
            continue
        seen.add(key)
        aid = mermaid_id(a, "E")
        bid = mermaid_id(b, "E")
        el = mermaid_label(lbl)[:40]
        lines.append(f'  {aid} -->|"{el}"| {bid}')

    return "```mermaid\n" + "\n".join(lines) + "\n```"


def render_flow_doc(data: dict[str, Any]) -> str:
    fn = data["apiName"]
    st = data.get("start") or {}
    obj_tr = st.get("object") or "—"
    trig = st.get("triggerType") or "—"

    lines = [
        f"# {data.get('label') or fn}",
        "",
        f"**Type:** {data.get('processType') or '—'} | **Status:** {data.get('status') or '—'} | **API Version:** {data.get('apiVersion') or '—'} | **Object/Trigger:** {obj_tr} / {trig}",
        "",
        "---",
        "",
        "## Summary",
        "",
        flow_summary_paragraph(data),
        "",
        "---",
        "",
        "## Flow / Component Diagram",
        "",
        render_internal_flow_mermaid(data),
        "",
        "---",
        "",
        "## Technical Details",
        "",
    ]

    # Variables table
    lines.append("### Variables")
    lines.append("")
    lines.append("| Name | Type | Input | Output | Default |")
    lines.append("|------|------|-------|--------|---------|")
    for v in data.get("variables") or []:
        lines.append(
            f"| {text_escape_md(v.get('name'))} | {text_escape_md(v.get('dataType'))} | {v.get('isInput')} | {v.get('isOutput')} | {text_escape_md(v.get('default'))} |"
        )
    if not data.get("variables"):
        lines.append("| — | — | — | — | — |")

    lines.append("")
    lines.append("### Decision Elements")
    lines.append("")
    for d in data.get("decisions") or []:
        lines.append(f"#### {text_escape_md(d.get('name'))}")
        lines.append("")
        lines.append(f"- **Default:** → `{md_cell(d.get('defaultConnector'))}` ({text_escape_md(d.get('defaultConnectorLabel'))})")
        for rule in d.get("rules") or []:
            lines.append(f"- **Rule:** {text_escape_md(rule.get('label') or rule.get('name'))} → `{md_cell(rule.get('connector'))}`")
            if rule.get("conditionLogic"):
                lines.append(f"  - Condition logic: `{text_escape_md(rule.get('conditionLogic'))}`")
            for c in rule.get("conditions") or []:
                lines.append(
                    f"  - `{text_escape_md(c.get('left'))}` {text_escape_md(c.get('operator'))} `{text_escape_md(c.get('right'))}`"
                )
        lines.append("")

    lines.append("### Record Operations")
    lines.append("")
    for section, title in (
        ("recordLookups", "Lookups"),
        ("recordCreates", "Creates"),
        ("recordUpdates", "Updates"),
        ("recordDeletes", "Deletes"),
    ):
        lines.append(f"#### {title}")
        lines.append("")
        lines.append("| Name | Object | Fault path | Filter logic |")
        lines.append("|------|--------|------------|--------------|")
        for ro in data.get(section) or []:
            lines.append(
                f"| {text_escape_md(ro.get('name'))} | {md_cell(ro.get('object'))} | `{md_cell(ro.get('faultConnector'))}` | {md_cell(ro.get('filterLogic'))} |"
            )
        if not data.get(section):
            lines.append("| — | — | — | — |")
        lines.append("")

    lines.append("### Record field assignments (creates and updates)")
    lines.append("")
    has_ia = False
    for ro in (data.get("recordCreates") or []) + (data.get("recordUpdates") or []):
        ias = ro.get("inputAssignments") or []
        if not ias:
            continue
        has_ia = True
        lines.append(f"- **{text_escape_md(ro.get('name'))}** ({ro.get('kind')}) on `{text_escape_md(ro.get('object'))}`:")
        for ia in ias:
            lines.append(f"  - `{text_escape_md(ia.get('field'))}` ← {text_escape_md(ia.get('value'))}")
    if not has_ia:
        lines.append("—")
    lines.append("")

    lines.append("### Actions")
    lines.append("")
    lines.append("| Name | Action | Type | Fault |")
    lines.append("|------|--------|------|-------|")
    for a in data.get("actionCalls") or []:
        lines.append(
            f"| {text_escape_md(a.get('name'))} | {text_escape_md(a.get('actionName'))} | {text_escape_md(a.get('actionType'))} | `{md_cell(a.get('faultConnector'))}` |"
        )
    if not data.get("actionCalls"):
        lines.append("| — | — | — | — |")
    lines.append("")
    lines.append("### Subflows")
    lines.append("")
    lines.append("| Name | Called flow | Fault |")
    lines.append("|------|-------------|-------|")
    for s in data.get("subflows") or []:
        lines.append(
            f"| {text_escape_md(s.get('name'))} | {text_escape_md(s.get('flowName'))} | `{md_cell(s.get('faultConnector'))}` |"
        )
    if not data.get("subflows"):
        lines.append("| — | — | — |")

    lines.append("")
    lines.append("### Fault paths")
    lines.append("")
    lines.append("Elements referencing a fault connector are listed in the Record Operations and Actions tables above.")
    lines.append("")

    if data.get("otherElements"):
        lines.append("### Other flow elements")
        lines.append("")
        for k, names in sorted(data["otherElements"].items()):
            lines.append(f"- **{k}:** {', '.join(names[:30])}" + (" ..." if len(names) > 30 else ""))
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("## Dependencies")
    lines.append("")
    deps = data.get("dependencies") or {}
    lines.append("- **Objects:** " + ", ".join(deps.get("objects") or ["—"]))
    lines.append("- **Subflows:** " + ", ".join(deps.get("subflows") or ["—"]))
    lines.append("- **Apex / invocable actions:** " + ", ".join(deps.get("apexActions") or ["—"]))
    lines.append("")
    lines.append("---")
    lines.append("")
    return "\n".join(lines)


# --- Object parsing ---

def parse_field_file(path: Path) -> dict[str, Any]:
    root = parse_xml(path)
    full_name = child_text(root, "fullName")
    label = child_text(root, "label")
    ftype = child_text(root, "type")
    required = child_text(root, "required")
    unique = child_text(root, "unique")
    ext_id = child_text(root, "externalId")
    desc = child_text(root, "description")
    inline_help = child_text(root, "inlineHelpText")
    refs = [child_text(r, "referenceTo") for r in root.findall(f"{NS}referenceTo")]
    refs = [r for r in refs if r]

    return {
        "fullName": full_name,
        "label": label,
        "type": ftype,
        "required": required,
        "unique": extId_display(unique, ext_id),
        "description": desc or inline_help,
        "referenceTo": refs,
    }


def extId_display(unique: str | None, external_id: str | None) -> str:
    if unique == "true":
        return "true"
    if external_id == "true":
        return "external id"
    return unique or ""


def parse_validation_rule(path: Path) -> dict[str, Any]:
    root = parse_xml(path)
    return {
        "fullName": child_text(root, "fullName"),
        "active": child_text(root, "active"),
        "errorConditionFormula": child_text(root, "errorConditionFormula"),
        "errorMessage": child_text(root, "errorMessage"),
    }


def parse_record_type(path: Path) -> dict[str, Any]:
    root = parse_xml(path)
    return {
        "fullName": child_text(root, "fullName"),
        "active": child_text(root, "active"),
        "description": child_text(root, "description"),
        "label": child_text(root, "label"),
    }


def parse_object_bundle(obj_dir: Path) -> dict[str, Any]:
    name = obj_dir.name
    om = obj_dir / f"{name}.object-meta.xml"
    root = parse_xml(om)

    fields_dir = obj_dir / "fields"
    fields: list[dict[str, Any]] = []
    if fields_dir.is_dir():
        for fp in sorted(fields_dir.glob("*.field-meta.xml")):
            fields.append(parse_field_file(fp))

    vrules: list[dict[str, Any]] = []
    vr_dir = obj_dir / "validationRules"
    if vr_dir.is_dir():
        for vp in sorted(vr_dir.glob("*.validationRule-meta.xml")):
            vrules.append(parse_validation_rule(vp))

    rtypes: list[dict[str, Any]] = []
    rt_dir = obj_dir / "recordTypes"
    if rt_dir.is_dir():
        for rp in sorted(rt_dir.glob("*.recordType-meta.xml")):
            rtypes.append(parse_record_type(rp))

    def list_simple(sub: str, pattern: str) -> list[str]:
        d = obj_dir / sub
        if not d.is_dir():
            return []
        return sorted(p.stem for p in d.glob(pattern))

    compact_layouts = list_simple("compactLayouts", "*.compactLayout-meta.xml")
    list_views = list_simple("listViews", "*.listView-meta.xml")
    web_links = list_simple("webLinks", "*.webLink-meta.xml")
    field_sets = list_simple("fieldSets", "*.fieldSet-meta.xml")
    business_processes = list_simple("businessProcesses", "*.businessProcess-meta.xml")

    return {
        "apiName": name,
        "label": child_text(root, "label") or name,
        "sharingModel": child_text(root, "sharingModel"),
        "nameField": child_text(
            root.find(f"{NS}nameField") if root.find(f"{NS}nameField") is not None else None,
            "label",
        ),
        "fields": fields,
        "validationRules": vrules,
        "recordTypes": rtypes,
        "compactLayouts": compact_layouts,
        "listViews": list_views,
        "webLinks": web_links,
        "fieldSets": field_sets,
        "businessProcesses": business_processes,
    }


def object_relationship_mermaid(all_objects: list[dict[str, Any]]) -> str:
    """Edges between the six objects based on lookup/MD on those objects only."""
    our = {o["apiName"] for o in all_objects}
    edges: set[tuple[str, str, str]] = set()
    for obj in all_objects:
        src = obj["apiName"]
        for f in obj.get("fields") or []:
            if f.get("type") not in ("Lookup", "MasterDetail"):
                continue
            for tgt in f.get("referenceTo") or []:
                if tgt in our:
                    edges.add((src, tgt, f.get("type") or "Lookup"))

    lines = ["graph LR"]
    for o in sorted(our):
        oid = mermaid_id(o, "OB")
        lines.append(f'  {oid}["{mermaid_label(o)}"]')
    for a, b, typ in sorted(edges):
        aid = mermaid_id(a, "OB")
        bid = mermaid_id(b, "OB")
        lines.append(f'  {aid} -->|"{mermaid_label(typ)}"| {bid}')
    if not edges:
        lines.append('  note["No Lookup/MasterDetail between these six objects in retrieved field metadata"]')

    return "```mermaid\n" + "\n".join(lines) + "\n```"


def object_summary_paragraph(data: dict[str, Any]) -> str:
    n = data["apiName"]
    nf = len(data.get("fields") or [])
    nv = len(data.get("validationRules") or [])
    nr = len(data.get("recordTypes") or [])
    return (
        f"The {n} object metadata in this project includes {nf} field definition file(s), {nv} validation rule(s), and {nr} record type(s). "
        f"These artifacts extend the standard Salesforce object with custom fields, validation, and segmentation used by processes and UIs in the org. "
        f"Relationships to other objects in this bundle appear where custom Lookup or Master-Detail fields reference those targets."
    )


def render_object_doc(data: dict[str, Any]) -> str:
    name = data["apiName"]
    lines = [
        f"# {name}",
        "",
        f"**Type:** CustomObject (standard object extension) | **Status:** Deployed metadata | **API Version:** (see field files) | **Object/Trigger:** {name}",
        "",
        "---",
        "",
        "## Summary",
        "",
        object_summary_paragraph(data),
        "",
        "---",
        "",
        "## Flow / Component Diagram",
        "",
        "Object-level relationship diagrams for the objects in this project are in [README.md](./README.md) (Architecture Diagram). This bundle does not contain a single executable flow; field and validation metadata is tabulated below.",
        "",
        "---",
        "",
        "## Technical Details",
        "",
        "### Fields",
        "",
        "| Label | API Name | Type | Required | Unique | Description |",
        "|-------|----------|------|----------|--------|-------------|",
    ]
    for f in data.get("fields") or []:
        lines.append(
            f"| {text_escape_md(f.get('label'))} | {text_escape_md(f.get('fullName'))} | {text_escape_md(f.get('type'))} | {text_escape_md(f.get('required'))} | {text_escape_md(str(f.get('unique')))} | {text_escape_md((f.get('description') or '')[:200])} |"
        )
    lines.append("")
    lines.append("### Relationships")
    lines.append("")
    rel_rows = []
    for f in data.get("fields") or []:
        if f.get("type") in ("Lookup", "MasterDetail") and f.get("referenceTo"):
            rel_rows.append(
                f"| {text_escape_md(f.get('fullName'))} | {text_escape_md(f.get('type'))} | {', '.join(f.get('referenceTo') or [])} |"
            )
    if rel_rows:
        lines.append("| Field | Kind | References |")
        lines.append("|-------|------|------------|")
        lines.extend(rel_rows)
    else:
        lines.append("No Lookup or Master-Detail fields found in retrieved field metadata for this object.")

    lines.append("")
    lines.append("### Validation rules")
    lines.append("")
    lines.append("| Rule Name | Condition | Error Message |")
    lines.append("|-----------|-----------|---------------|")
    for v in data.get("validationRules") or []:
        cond = (v.get("errorConditionFormula") or "")[:500]
        msg = (v.get("errorMessage") or "")[:300]
        lines.append(
            f"| {text_escape_md(v.get('fullName'))} | `{text_escape_md(cond)}` | {text_escape_md(msg)} |"
        )
    lines.append("")
    lines.append("### Record types")
    lines.append("")
    for r in data.get("recordTypes") or []:
        lines.append(f"- **{text_escape_md(r.get('fullName'))}** (active: {r.get('active')}): {text_escape_md(r.get('description'))}")
    if not data.get("recordTypes"):
        lines.append("- —")
    lines.append("")
    lines.append("### Page layouts")
    lines.append("")
    lines.append("No `layouts/` metadata is present in this project snapshot for this object.")
    lines.append("")
    lines.append("### Compact layouts")
    lines.append("")
    lines.append(", ".join(data.get("compactLayouts") or ["—"]))
    lines.append("")
    lines.append("### List views (metadata files)")
    lines.append("")
    lines.append(", ".join(data.get("listViews") or ["—"]))
    lines.append("")
    lines.append("### Web links")
    lines.append("")
    lines.append(", ".join(data.get("webLinks") or ["—"]))
    lines.append("")
    lines.append("### Field sets")
    lines.append("")
    lines.append(", ".join(data.get("fieldSets") or ["—"]))
    lines.append("")
    lines.append("### Business processes")
    lines.append("")
    lines.append(", ".join(data.get("businessProcesses") or ["—"]))
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## Dependencies")
    lines.append("")
    refs: set[str] = set()
    for f in data.get("fields") or []:
        for r in f.get("referenceTo") or []:
            refs.add(r)
    lines.append("- **Referenced objects (lookup targets):** " + ", ".join(sorted(refs) or ["—"]))
    lines.append("")
    lines.append("---")
    lines.append("")
    return "\n".join(lines)


def trigger_object_column(data: dict[str, Any]) -> str:
    st = data.get("start") or {}
    obj = st.get("object")
    tt = st.get("triggerType")
    if obj:
        return f"{obj} ({tt or ''})"
    return "—"


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    force_default = repo / "force-app" / "main" / "default"
    docs = repo / "docs"

    if not force_default.is_dir():
        print(f"Missing {force_default}", file=sys.stderr)
        return 1

    chapters = discover_chapters(force_default)
    if not chapters:
        print("No metadata chapters found.", file=sys.stderr)
        return 1

    docs.mkdir(exist_ok=True)

    # --- Flows ---
    flow_dir = force_default / "flows"
    all_flows: list[dict[str, Any]] = []
    if flow_dir.is_dir():
        for fp in sorted(flow_dir.glob("*.flow-meta.xml")):
            try:
                all_flows.append(parse_flow_file(fp))
            except Exception as e:
                print(f"Warning: parse {fp}: {e}", file=sys.stderr)

    obj_graph_mermaid = ""
    objects_data: list[dict[str, Any]] = []
    obj_root = force_default / "objects"
    if obj_root.is_dir():
        for od in sorted(obj_root.iterdir()):
            if od.is_dir() and (od / f"{od.name}.object-meta.xml").exists():
                try:
                    objects_data.append(parse_object_bundle(od))
                except Exception as e:
                    print(f"Warning: parse object {od}: {e}", file=sys.stderr)
        obj_graph_mermaid = object_relationship_mermaid(objects_data)

    # Chapter: flows README
    if any(c[0] == "flows" for c in chapters):
        fchapter = docs / "flows"
        fchapter.mkdir(parents=True, exist_ok=True)
        g1, g2 = build_flow_chapter_graphs(all_flows)

        readme_f = [
            "# Chapter: Flows",
            "",
            "## Overview",
            "",
            f"This chapter documents **{len(all_flows)}** Salesforce Flow components. Flows automate business processes with declarative logic including record-triggered automation, screen flows, autolaunched flows, and subflow composition.",
            "",
            "## Architecture Diagram",
            "",
            "### Record-triggered flows and objects",
            "",
            "```mermaid",
            g1,
            "```",
            "",
            "### Subflow call graph",
            "",
            "```mermaid",
            g2,
            "```",
            "",
            "## Component Index",
            "",
            "| # | Component Name | Type | Trigger/Object | Status |",
            "|---|---------------|------|----------------|--------|",
        ]
        for i, fd in enumerate(all_flows, 1):
            nm = fd["apiName"]
            readme_f.append(
                f"| {i} | [{nm}](./{nm}.md) | {text_escape_md(fd.get('processType'))} | {text_escape_md(trigger_object_column(fd))} | {text_escape_md(fd.get('status'))} |"
            )
        readme_f.extend(["", "---", ""])
        (fchapter / "README.md").write_text("\n".join(readme_f), encoding="utf-8")

        for fd in all_flows:
            (fchapter / f"{fd['apiName']}.md").write_text(render_flow_doc(fd), encoding="utf-8")

    # Chapter: objects README
    if any(c[0] == "objects" for c in chapters):
        ochapter = docs / "objects"
        ochapter.mkdir(parents=True, exist_ok=True)
        readme_o = [
            "# Chapter: Objects",
            "",
            "## Overview",
            "",
            f"This chapter documents **{len(objects_data)}** object metadata bundles (standard objects with retrieved custom fields, validation rules, and related configuration).",
            "",
            "## Architecture Diagram",
            "",
            "Relationships (Lookup / Master-Detail) **between the objects present in this project** are shown below. Cross-object references to types not included in this snapshot appear only in field tables and dependency sections.",
            "",
            obj_graph_mermaid,
            "",
            "## Component Index",
            "",
            "| # | Component Name | Type | Trigger/Object | Status |",
            "|---|---------------|------|----------------|--------|",
        ]
        for i, od in enumerate(objects_data, 1):
            n = od["apiName"]
            readme_o.append(f"| {i} | [{n}](./{n}.md) | CustomObject | {n} | — |")
        readme_o.extend(["", "---", ""])
        (ochapter / "README.md").write_text("\n".join(readme_o), encoding="utf-8")

        for od in objects_data:
            (ochapter / f"{od['apiName']}.md").write_text(render_object_doc(od), encoding="utf-8")

    # Every other top-level metadata folder (classes, triggers, lwc, aura, namedCredentials, etc.)
    for child in sorted(force_default.iterdir()):
        if not child.is_dir() or child.name.startswith("."):
            continue
        if child.name in ("flows", "objects"):
            continue
        if not list_components(child):
            continue
        write_generic_chapter(child, docs / child.name, human_title(child.name))

    # Master README
    master = ["# Salesforce Org — Full Documentation", "", "Documentation generated from local metadata at `force-app/main/default`.", "", "## Chapters", "", "| # | Chapter | Metadata Type | Total Components |", "|---|---------|---------------|------------------|"]
    for i, (folder, count, title) in enumerate(chapters, 1):
        master.append(f"| {i} | [{title}](./{folder}/README.md) | {folder} | {count} |")
    master.extend(["", "---", ""])
    (docs / "README.md").write_text("\n".join(master), encoding="utf-8")

    print(f"Generated documentation under {docs}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
