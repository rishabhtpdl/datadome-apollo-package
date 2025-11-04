//
//  NetworkInterceptorProvider.swift
//  DataDomeApollo
//
//  Created by Mohamed Hajlaoui on 31/03/2021.
//

import Foundation
import Apollo
#if !COCOAPODS
import ApolloAPI
#endif

public class DataDomeInterceptorProvider: InterceptorProvider {
    
    /// The apollo store
    private let store: ApolloStore
    
    /// The url session client. Use DataDomeURLSessionClient
    private let client: ApolloURLSession
    
    /// The list of custom GraphQL interceptors to add
    private let customGraphQLInterceptors: [any GraphQLInterceptor]
    
    /// Creates an interceptor provider with a setup instance of DataDome
    /// - Parameters:
    ///   - store: The apollo store
    ///   - client: The URLSession client
    ///   - customGraphQLInterceptors: Custom GraphQL interceptors to add (DataDome interceptor will be added automatically)
    public init(store: ApolloStore,
                client: ApolloURLSession,
                customGraphQLInterceptors: [any GraphQLInterceptor] = []) {
        self.store = store
        self.client = client
        self.customGraphQLInterceptors = customGraphQLInterceptors
    }
    
    /// Provides GraphQL interceptors (pre/post-flight GraphQL processing)
    /// - Parameter operation: The GraphQL operation
    /// - Returns: The list of GraphQL interceptors
    public func graphQLInterceptors<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> [any GraphQLInterceptor] {
        var interceptors = DefaultInterceptorProvider.shared.graphQLInterceptors(for: operation)
        
        // Add custom interceptors
        interceptors.append(contentsOf: customGraphQLInterceptors)
        
        return interceptors
    }
    
    /// Provides cache interceptor (cache read/write operations)
    /// - Parameter operation: The GraphQL operation
    /// - Returns: The cache interceptor
    public func cacheInterceptor<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> any CacheInterceptor {
        return DefaultInterceptorProvider.shared.cacheInterceptor(for: operation)
    }
    
    /// Provides HTTP interceptors (URLRequest/HTTPResponse processing)
    /// - Parameter operation: The GraphQL operation
    /// - Returns: The list of HTTP interceptors
    public func httpInterceptors<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> [any HTTPInterceptor] {
        var interceptors = DefaultInterceptorProvider.shared.httpInterceptors(for: operation)
        // Add DataDome interceptor to validate HTTP responses
        interceptors.append(DataDomeResponseInterceptor())
        return interceptors
    }
    
    /// Provides response parser (parses raw response data into GraphQLResponse)
    /// - Parameter operation: The GraphQL operation
    /// - Returns: The response parsing interceptor
    public func responseParser<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> any ResponseParsingInterceptor {
        return DefaultInterceptorProvider.shared.responseParser(for: operation)
    }
}
