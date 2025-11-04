//
//  DataDomeResponseInterceptor.swift
//  DataDomeApollo
//
//  Created by Mohamed Hajlaoui on 31/03/2021.
//

import Apollo
import DataDomeSDK
#if !COCOAPODS
import ApolloAPI
#endif

/// The DataDome interceptor. Use this to get your networking pipeline protected.
/// In Apollo 2.0, this is an HTTPInterceptor to access raw HTTP responses and data.
public class DataDomeResponseInterceptor: HTTPInterceptor {
    public var id: String = UUID().uuidString
    
    /// Expose the initializer publicly
    public init() {}
    
    /// Intercepts HTTP responses before they are parsed into GraphQL responses
    /// - Parameters:
    ///   - chain: The interceptor result stream
    ///   - request: The GraphQL request
    ///   - response: The HTTP response stream
    public func intercept<Operation: GraphQLOperation>(
        chain: InterceptorResultStream<HTTPResponse>,
        request: GraphQLRequest<Operation>,
        response: HTTPResponse
    ) async {
        // Get the response page delegate from the request context
        let responsePageDelegate = (request.context as? ProtectedRequestContext)?.responsePageDelegate
        
        // Validate the HTTP response through DataDome
        await validateResponse(
            chain: chain,
            request: request,
            response: response,
            responsePageDelegate: responsePageDelegate
        )
    }
    
    private func validateResponse<Operation: GraphQLOperation>(
        chain: InterceptorResultStream<HTTPResponse>,
        request: GraphQLRequest<Operation>,
        response: HTTPResponse,
        responsePageDelegate: CaptchaDelegate?
    ) async {
        // Use a continuation to handle async validation result
        let validationResult = await withCheckedContinuation { (continuation: CheckedContinuation<ValidationResult, Never>) in
            let validator = ResponseValidator(
                request: request,
                response: response.httpResponse,
                data: response.rawData,
                responsePageDelegate: responsePageDelegate
            )
            
            let handler = DataDomeHTTPHandler(
                request: request,
                onResult: { result in
                    continuation.resume(returning: result)
                }
            )
            
            validator.delegate = handler
            validator.validate()
        }
        
        // Handle the validation result
        switch validationResult {
        case .proceed:
            // Forward the response through the chain
            await chain.proceed(response)
        case .retry:
            // Throw RequestChain.Retry to trigger a retry
            // In Apollo 2.0, retries are triggered by throwing the error
            await chain.proceed(response, mapErrors: { _ in [RequestChain.Retry()] })
        }
    }
}

private enum ValidationResult {
    case proceed
    case retry
}

/// Handler for DataDome validation results when processing HTTP responses
private class DataDomeHTTPHandler<Operation: GraphQLOperation>: ResponseValidatorDelegate {
    let request: GraphQLRequest<Operation>
    let onResult: (ValidationResult) -> Void
    private var hasHandled = false
    
    init(
        request: GraphQLRequest<Operation>,
        onResult: @escaping (ValidationResult) -> Void
    ) {
        self.request = request
        self.onResult = onResult
    }
    
    func shouldIgnore(request: Requestable) {
        guard !hasHandled else { return }
        hasHandled = true
        onResult(.proceed)
    }
    
    func didFailWith(error: Error) {
        guard !hasHandled else { return }
        hasHandled = true
        onResult(.proceed)
    }
    
    func shouldRetry(request: Requestable) {
        guard !hasHandled else { return }
        hasHandled = true
        EventTracker.shared.log(request: request, integrationMode: .apollo)
        onResult(.retry)
    }
}

// Extension to make GraphQLRequest conform to Requestable for DataDome SDK
extension GraphQLRequest: @retroactive Requestable {
    public var url: URL? {
        operation.operationDefinition.graphQLEndpoint
    }
    
    public func header(forField field: String) -> String? {
        additionalHeaders[field]
    }
}
