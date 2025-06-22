//
//  AsyncLockedMacro.swift
//  SwiftRepo
//
//  Created by Timothy Moose on 6/22/25.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct SwiftRepoMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AsyncLockedMacro.self,
    ]
}

/// A macro that adds async locking to functions by generating a locked implementation
/// and a replacement function that shadows the original
public struct AsyncLockedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw CustomError("`@AsyncLocked` can only be applied to functions")
        }

        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            throw CustomError("`@AsyncLocked` can only be applied to async functions")
        }

        guard let originalBody = funcDecl.body else {
            throw CustomError("`@AsyncLocked` requires a function body")
        }

        let originalName = funcDecl.name.text
        
        // Create a unique identifier based on function name and parameters to handle overloads
        let parameterNames = funcDecl.signature.parameterClause.parameters.map { param in
            if param.firstName.tokenKind == .wildcard {
                return "_"
            } else {
                return param.firstName.text
            }
        }.joined(separator: "_")
        
        let uniqueName = parameterNames.isEmpty ? originalName : "\(originalName)_\(parameterNames)"
        let lockName = "__asyncLock_\(uniqueName)"
        let lockedImplName = "__locked_\(uniqueName)"

        // 1. Generate the lock property
        let lockProperty = VariableDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.private))],
            bindingSpecifier: .keyword(.let)
        ) {
            PatternBindingSyntax(
                pattern: IdentifierPatternSyntax(identifier: .identifier(lockName)),
                initializer: InitializerClauseSyntax(
                    value: FunctionCallExprSyntax(
                        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("AsyncLock")),
                        leftParen: .leftParenToken(),
                        arguments: LabeledExprListSyntax([]),
                        rightParen: .rightParenToken()
                    )
                )
            )
        }

        // 2. Generate the private locked implementation
        let lockedImpl = FunctionDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.private))],
            name: .identifier(lockedImplName),
            signature: funcDecl.signature,
            body: originalBody
        )

        return [
            DeclSyntax(lockProperty),
            DeclSyntax(lockedImpl)
        ]
    }
}

struct CustomError: Error, CustomStringConvertible {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var description: String { message }
}
