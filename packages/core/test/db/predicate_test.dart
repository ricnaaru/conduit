import 'package:conduit_core/conduit_core.dart';
import 'package:test/test.dart';

void main() {
  group("QueryPredicate.and", () {
    test("Duplicate keys are replaced", () {
      final p1 = QueryPredicate("p=@p", {"p": 1});
      final p2 = QueryPredicate("p=@p", {"p": 2});
      final combined = QueryPredicate.and([p1, p2]);
      expect(combined.format, "(p=@p AND p=@p0)");
      expect(combined.parameters, {"p": 1, "p0": 2});
    });

    test("Multiple duplicate keys are replaced", () {
      final p1 = QueryPredicate("p=@p", {"p": 1});
      final p2 = QueryPredicate("p=@p", {"p": 2});
      final p3 = QueryPredicate("p=@p", {"p": 3});
      final combined = QueryPredicate.and([p1, p2, p3]);
      expect(combined.format, "(p=@p AND p=@p0 AND p=@p1)");
      expect(combined.parameters, {"p": 1, "p0": 2, "p1": 3});
    });

    test("If empty list, return empty predicate", () {
      expect(QueryPredicate.and([]).format, "");
      expect(QueryPredicate.and([]).parameters, {});
    });

    // No Longer allowing null values
    // test("If null, return empty predicate", () {
    //   expect(QueryPredicate.and(null).format, "");
    //   expect(QueryPredicate.and(null).parameters, {});
    // });

    test("If only one element in list, return that element", () {
      final valid = QueryPredicate("x=@a", {"a": 0});
      final p = QueryPredicate.and([valid]);
      expect(p.format, valid.format);
      expect(p.parameters, valid.parameters);
    });

    test("If and'ing empty predicate, ignore it", () {
      final valid = QueryPredicate("x=@a", {"a": 0});
      final p = QueryPredicate.and([valid, QueryPredicate.empty()]);
      expect(p.format, valid.format);
      expect(p.parameters, valid.parameters);
    });

    // Not allowing null values
    // test("If and'ing null predicate, ignore it", () {
    //   final valid = QueryPredicate("x=@a", {"a": 0});
    //   final p = QueryPredicate.and([valid, null]);
    //   expect(p.format, valid.format);
    //   expect(p.parameters, valid.parameters);
    // });

    test("And'ing predicate with no parameters", () {
      final valid = QueryPredicate("x=y");
      final p = QueryPredicate.and([valid]);
      expect(p.format, valid.format);
      expect(p.parameters, {});
    });
  });
}
