/**
 * Test class for LIM_Mirakl_Integration
 */
@isTest
private class LIM_Mirakl_Integration_Test {
    private class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success":true}');
            res.setStatus('OK');
            return res;
        }
    }

    private class MockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('Not Found');
            res.setStatus('Not Found');
            return res;
        }
    }

    @isTest
    static void callMiraklApi_emptyInput_returnsEmptyList() {
        Test.startTest();
        List<LIM_Mirakl_Integration.InvocableOutput> outputs = LIM_Mirakl_Integration.callMiraklApi(
            new List<LIM_Mirakl_Integration.InvocableInput>()
        );
        Test.stopTest();
        System.assertEquals(0, outputs.size(), 'Should return empty list');
    }

    @isTest
    static void callMiraklApi_nullInput_returnsEmptyList() {
        Test.startTest();
        List<LIM_Mirakl_Integration.InvocableOutput> outputs = LIM_Mirakl_Integration.callMiraklApi(null);
        Test.stopTest();
        System.assertEquals(0, outputs.size(), 'Should return empty list');
    }

    @isTest
    static void callMiraklApi_validInput_returnsResult() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        LIM_Mirakl_Integration.InvocableInput invInput = new LIM_Mirakl_Integration.InvocableInput();
        invInput.httpMethod = 'GET';
        invInput.relativePath = '/api/orders';
        invInput.requestBody = null;

        Test.startTest();
        List<LIM_Mirakl_Integration.InvocableOutput> outputs = LIM_Mirakl_Integration.callMiraklApi(
            new List<LIM_Mirakl_Integration.InvocableInput>{ invInput }
        );
        Test.stopTest();

        System.assertEquals(1, outputs.size(), 'Should return one output');
        System.assertEquals(true, outputs[0].success, 'Call should succeed');
        System.assertEquals('200', outputs[0].statusCode, 'Status should be 200');
        System.assertEquals('{"success":true}', outputs[0].responseBody, 'Body should match mock');
        System.assertEquals(null, outputs[0].errorMessage, 'No error message');
    }

    @isTest
    static void executeRequests_emptyInput_returnsEmptyList() {
        Test.startTest();
        List<LIM_Mirakl_Integration.Output> results = LIM_Mirakl_Integration.executeRequests(
            new List<LIM_Mirakl_Integration.Input>()
        );
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Should return empty list');
    }

    @isTest
    static void executeRequests_nullInput_returnsEmptyList() {
        Test.startTest();
        List<LIM_Mirakl_Integration.Output> results = LIM_Mirakl_Integration.executeRequests(null);
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Should return empty list');
    }

    @isTest
    static void executeRequests_validRequest_success() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        LIM_Mirakl_Integration.Input req = new LIM_Mirakl_Integration.Input();
        req.httpMethod = 'POST';
        req.relativePath = '/api/shops';
        req.requestBody = '{"test":true}';

        Test.startTest();
        List<LIM_Mirakl_Integration.Output> results = LIM_Mirakl_Integration.executeRequests(
            new List<LIM_Mirakl_Integration.Input>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].success, 'Should succeed');
        System.assertEquals(200, results[0].statusCode, 'StatusCode should be 200');
        System.assertEquals('{"success":true}', results[0].responseBody, 'Response body should match mock');
        System.assertEquals(null, results[0].errorMessage, 'No error message');
    }

    @isTest
    static void executeRequests_invalidMethod_returnsError() {
        LIM_Mirakl_Integration.Input req = new LIM_Mirakl_Integration.Input();
        req.httpMethod = 'INVALID';
        req.relativePath = '/api/test';

        Test.startTest();
        List<LIM_Mirakl_Integration.Output> results = LIM_Mirakl_Integration.executeRequests(
            new List<LIM_Mirakl_Integration.Input>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
        System.assert(results[0].errorMessage.contains('Invalid HTTP method'), 'Should mention invalid method');
    }

    @isTest
    static void executeRequests_blankPath_returnsError() {
        LIM_Mirakl_Integration.Input req = new LIM_Mirakl_Integration.Input();
        req.httpMethod = 'GET';
        req.relativePath = '';

        Test.startTest();
        List<LIM_Mirakl_Integration.Output> results = LIM_Mirakl_Integration.executeRequests(
            new List<LIM_Mirakl_Integration.Input>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
        System.assert(results[0].errorMessage.contains('Relative path'), 'Should mention path');
    }

    @isTest
    static void executeRequests_blankMethod_returnsError() {
        LIM_Mirakl_Integration.Input req = new LIM_Mirakl_Integration.Input();
        req.httpMethod = '';
        req.relativePath = '/api/test';

        Test.startTest();
        List<LIM_Mirakl_Integration.Output> results = LIM_Mirakl_Integration.executeRequests(
            new List<LIM_Mirakl_Integration.Input>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
    }

    @isTest
    static void executeRequests_httpError_returnsErrorResult() {
        Test.setMock(HttpCalloutMock.class, new MockError());
        LIM_Mirakl_Integration.Input req = new LIM_Mirakl_Integration.Input();
        req.httpMethod = 'GET';
        req.relativePath = '/api/orders';

        Test.startTest();
        List<LIM_Mirakl_Integration.Output> results = LIM_Mirakl_Integration.executeRequests(
            new List<LIM_Mirakl_Integration.Input>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assertEquals(404, results[0].statusCode, 'StatusCode should be 404');
        System.assert(results[0].errorMessage != null, 'Error message should be set');
    }

    @isTest
    static void executeRequests_pathWithoutLeadingSlash_buildsCorrectEndpoint() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        LIM_Mirakl_Integration.Input req = new LIM_Mirakl_Integration.Input();
        req.httpMethod = 'GET';
        req.relativePath = 'api/orders';

        Test.startTest();
        List<LIM_Mirakl_Integration.Output> results = LIM_Mirakl_Integration.executeRequests(
            new List<LIM_Mirakl_Integration.Input>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].success, 'Path should be normalized and call should succeed');
    }
}