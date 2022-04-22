import Foundation

protocol TypedPredicateProtocol: NSPredicate { associatedtype Root }

final class CompoundPredicate<Root>: NSCompoundPredicate, TypedPredicateProtocol {}

final class ComparisonPredicate<Root>: NSComparisonPredicate, TypedPredicateProtocol {
	convenience init<Value>(_ keyPath: KeyPath<Root, Value>, _ operation: NSComparisonPredicate.Operator, _ value: Any?) {
		let ex1 = \Root.self == keyPath ? NSExpression.expressionForEvaluatedObject() : NSExpression(forKeyPath: keyPath)
		let ex2 = NSExpression(forConstantValue: value)
		self.init(leftExpression: ex1, rightExpression: ex2, modifier: .direct, type: operation)
	}
	convenience init<Value>(_ value: Any?, _ operation: NSComparisonPredicate.Operator, _ keyPath: KeyPath<Root, Value>) {
		let ex1 = NSExpression(forConstantValue: value)
		let ex2 = \Root.self == keyPath ? NSExpression.expressionForEvaluatedObject() : NSExpression(forKeyPath: keyPath)
		self.init(leftExpression: ex1, rightExpression: ex2, modifier: .direct, type: operation)
	}
}

//MARK: compound operators

func && <LHS: TypedPredicateProtocol, RHS: TypedPredicateProtocol>(lhs: LHS, rhs: RHS) -> CompoundPredicate<LHS.Root> where LHS.Root == RHS.Root {
	CompoundPredicate(type: .and, subpredicates: [lhs, rhs])
}

func || <LHS: TypedPredicateProtocol, RHS: TypedPredicateProtocol>(lhs: LHS, rhs: RHS) -> CompoundPredicate<LHS.Root> where LHS.Root == RHS.Root {
	CompoundPredicate(type: .or, subpredicates: [lhs, rhs])
}

prefix func ! <TP: TypedPredicateProtocol>(p: TP) -> CompoundPredicate<TP.Root> {
	CompoundPredicate(type: .not, subpredicates: [p])
}

//MARK: comparison operators

func == <E: Equatable, R, K: KeyPath<R, E>>(keyPath: K, value: E) -> ComparisonPredicate<R> {
	ComparisonPredicate(keyPath, .equalTo, value)
}

func != <E: Equatable, R, K: KeyPath<R, E>>(keyPath: K, value: E) -> ComparisonPredicate<R> {
	ComparisonPredicate(keyPath, .notEqualTo, value)
}

func > <C: Equatable, R, K: KeyPath<R, C>>(keyPath: K, value: C) -> ComparisonPredicate<R> {
	ComparisonPredicate(keyPath, .greaterThan, value)
}

func < <C: Equatable, R, K: KeyPath<R, C>>(keyPath: K, value: C) -> ComparisonPredicate<R> {
	ComparisonPredicate(keyPath, .lessThan, value)
}

func <= <C: Equatable, R, K: KeyPath<R, C>>(keyPath: K, value: C) -> ComparisonPredicate<R> {
	ComparisonPredicate(keyPath, .lessThanOrEqualTo, value)
}

func >= <C: Equatable, R, K: KeyPath<R, C>>(keyPath: K, value: C) -> ComparisonPredicate<R> {
	ComparisonPredicate(keyPath, .greaterThanOrEqualTo, value)
}

func === <S: Sequence, R, K: KeyPath<R, S.Element>>(keyPath: K, values: S) -> ComparisonPredicate<R> where S.Element: Equatable {
	ComparisonPredicate(keyPath, .in, values)
}
