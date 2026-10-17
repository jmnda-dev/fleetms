class ConditionEvaluator {
  /// Evaluates an item's visible_when condition against current answers and statuses.
  /// 
  /// [condition] is a Map representing the conditional logic tree.
  /// [answers] maps item ids to their current values (strings or lists of strings).
  /// [statuses] maps item ids to their computed statuses (e.g. 'pass', 'fail', 'answered').
  static bool isVisible(Map<String, dynamic>? condition, Map<String, dynamic> answers, Map<String, String> statuses) {
    if (condition == null || condition.isEmpty) {
      return true;
    }
    
    final rules = (condition['rules'] as List<dynamic>?) ?? [];
    final op = condition['op'] as String?;
    
    switch (op) {
      case 'any':
        return rules.any((rule) => _eval(rule as Map<String, dynamic>, answers, statuses));
      case 'not':
        return !rules.any((rule) => _eval(rule as Map<String, dynamic>, answers, statuses));
      default:
        // 'all' or default
        if (rules.isEmpty) return true;
        return rules.every((rule) => _eval(rule as Map<String, dynamic>, answers, statuses));
    }
  }

  static bool _eval(Map<String, dynamic> rule, Map<String, dynamic> answers, Map<String, String> statuses) {
    if (rule['rules'] != null) {
      return isVisible(rule, answers, statuses);
    }
    return _leaf(rule, answers, statuses);
  }

  static bool _leaf(Map<String, dynamic> rule, Map<String, dynamic> answers, Map<String, String> statuses) {
    final itemId = rule['item'] as String?;
    if (itemId == null) return false;
    
    final value = answers[itemId];
    final status = statuses[itemId];
    
    final op = rule['op'] as String?;
    final ruleValue = rule['value'];
    
    switch (op) {
      case 'answered':
        return status != null && status != 'skipped';
      case 'failed':
        return status == 'fail';
      case 'eq':
        return value?.toString() == ruleValue?.toString();
      case 'neq':
        return value?.toString() != ruleValue?.toString();
      case 'in':
        final list = (ruleValue is List) ? ruleValue : [ruleValue];
        return list.any((e) => e?.toString() == value?.toString());
      case 'gt':
        return _compare(value, ruleValue) == _CompareResult.gt;
      case 'gte':
        final res = _compare(value, ruleValue);
        return res == _CompareResult.gt || res == _CompareResult.eq;
      case 'lt':
        return _compare(value, ruleValue) == _CompareResult.lt;
      case 'lte':
        final res = _compare(value, ruleValue);
        return res == _CompareResult.lt || res == _CompareResult.eq;
      default:
        return true;
    }
  }

  static _CompareResult _compare(dynamic a, dynamic b) {
    final x = _toNumber(a);
    final y = _toNumber(b);
    if (x == null || y == null) {
      return _CompareResult.error;
    }
    if (x > y) return _CompareResult.gt;
    if (x < y) return _CompareResult.lt;
    return _CompareResult.eq;
  }

  static double? _toNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

enum _CompareResult { gt, lt, eq, error }
