/// Curated Daily DSA & LeetCode Coding Problem Service for CSE Students.
class DsaProblem {
  final String title;
  final String difficulty; // Easy, Medium, Hard
  final String topic; // Arrays, Strings, Trees, Graphs, DP, Two Pointers
  final String description;
  final String exampleInput;
  final String exampleOutput;
  final String hint;
  final String timeComplexity;
  final String spaceComplexity;
  final String pythonSolution;
  final String cppSolution;

  const DsaProblem({
    required this.title,
    required this.difficulty,
    required this.topic,
    required this.description,
    required this.exampleInput,
    required this.exampleOutput,
    required this.hint,
    required this.timeComplexity,
    required this.spaceComplexity,
    required this.pythonSolution,
    required this.cppSolution,
  });
}

class DsaProblemService {
  static final DsaProblemService _instance = DsaProblemService._internal();
  factory DsaProblemService() => _instance;
  DsaProblemService._internal();

  static const List<DsaProblem> _problemBank = [
    DsaProblem(
      title: 'Two Sum',
      difficulty: 'Easy',
      topic: 'Hash Map / Arrays',
      description: 'Given an array of integers `nums` and an integer `target`, return indices of the two numbers such that they add up to `target`.',
      exampleInput: 'nums = [2,7,11,15], target = 9',
      exampleOutput: '[0, 1]',
      hint: 'Use a hash map to store the complement (target - num) and its index while iterating in a single pass.',
      timeComplexity: 'O(N)',
      spaceComplexity: 'O(N)',
      pythonSolution: '''def twoSum(nums, target):
    seen = {}
    for i, n in enumerate(nums):
        diff = target - n
        if diff in seen:
            return [seen[diff], i]
        seen[n] = i
    return []''',
      cppSolution: '''vector<int> twoSum(vector<int>& nums, int target) {
    unordered_map<int, int> seen;
    for (int i = 0; i < nums.size(); i++) {
        int diff = target - nums[i];
        if (seen.count(diff)) return {seen[diff], i};
        seen[nums[i]] = i;
    }
    return {};
}''',
    ),
    DsaProblem(
      title: 'Valid Palindrome',
      difficulty: 'Easy',
      topic: 'Two Pointers / Strings',
      description: 'A phrase is a palindrome if, after converting all uppercase letters into lowercase letters and removing all non-alphanumeric characters, it reads the same forward and backward.',
      exampleInput: 's = "A man, a plan, a canal: Panama"',
      exampleOutput: 'true',
      hint: 'Use two pointers (left at start, right at end) and skip non-alphanumeric characters.',
      timeComplexity: 'O(N)',
      spaceComplexity: 'O(1)',
      pythonSolution: '''def isPalindrome(s: str) -> bool:
    l, r = 0, len(s) - 1
    while l < r:
        while l < r and not s[l].isalnum(): l += 1
        while l < r and not s[r].isalnum(): r -= 1
        if s[l].lower() != s[r].lower(): return False
        l += 1; r -= 1
    return True''',
      cppSolution: '''bool isPalindrome(string s) {
    int l = 0, r = s.size() - 1;
    while (l < r) {
        while (l < r && !isalnum(s[l])) l++;
        while (l < r && !isalnum(s[r])) r--;
        if (tolower(s[l]) != tolower(s[r])) return false;
        l++; r--;
    }
    return true;
}''',
    ),
    DsaProblem(
      title: 'Best Time to Buy and Sell Stock',
      difficulty: 'Easy',
      topic: 'Dynamic Programming / Greedy',
      description: 'You are given an array `prices` where `prices[i]` is the price of a given stock on the `i-th` day. Maximize your profit by choosing a single day to buy one stock and choosing a different day in the future to sell that stock.',
      exampleInput: 'prices = [7,1,5,3,6,4]',
      exampleOutput: '5 (Buy on day 2 at price 1, sell on day 5 at price 6)',
      hint: 'Keep track of the minimum buying price seen so far and update maximum profit at each step.',
      timeComplexity: 'O(N)',
      spaceComplexity: 'O(1)',
      pythonSolution: '''def maxProfit(prices: list[int]) -> int:
    min_price = float('inf')
    max_prof = 0
    for p in prices:
        min_price = min(min_price, p)
        max_prof = max(max_prof, p - min_price)
    return max_prof''',
      cppSolution: '''int maxProfit(vector<int>& prices) {
    int min_price = INT_MAX, max_prof = 0;
    for (int p : prices) {
        min_price = min(min_price, p);
        max_prof = max(max_prof, p - min_price);
    }
    return max_prof;
}''',
    ),
    DsaProblem(
      title: 'Maximum Subarray (Kadane\'s Algorithm)',
      difficulty: 'Medium',
      topic: 'Dynamic Programming / Arrays',
      description: 'Given an integer array `nums`, find the subarray with the largest sum, and return its sum.',
      exampleInput: 'nums = [-2,1,-3,4,-1,2,1,-5,4]',
      exampleOutput: '6 ([4,-1,2,1])',
      hint: 'At each index, decide whether to add the current number to the existing subarray sum or start a fresh subarray.',
      timeComplexity: 'O(N)',
      spaceComplexity: 'O(1)',
      pythonSolution: '''def maxSubArray(nums: list[int]) -> int:
    cur_sum = max_sum = nums[0]
    for n in nums[1:]:
        cur_sum = max(n, cur_sum + n)
        max_sum = max(max_sum, cur_sum)
    return max_sum''',
      cppSolution: '''int maxSubArray(vector<int>& nums) {
    int cur_sum = nums[0], max_sum = nums[0];
    for (int i = 1; i < nums.size(); i++) {
        cur_sum = max(nums[i], cur_sum + nums[i]);
        max_sum = max(max_sum, cur_sum);
    }
    return max_sum;
}''',
    ),
    DsaProblem(
      title: 'Merge Two Sorted Lists',
      difficulty: 'Easy',
      topic: 'Linked List / Recursion',
      description: 'You are given the heads of two sorted linked lists `list1` and `list2`. Merge the two lists into one sorted list and return the head of the new list.',
      exampleInput: 'list1 = [1,2,4], list2 = [1,3,4]',
      exampleOutput: '[1,1,2,3,4,4]',
      hint: 'Use a dummy node and attach the smaller node between list1 and list2 iteratively.',
      timeComplexity: 'O(N + M)',
      spaceComplexity: 'O(1)',
      pythonSolution: '''def mergeTwoLists(l1, l2):
    dummy = cur = ListNode(0)
    while l1 and l2:
        if l1.val < l2.val:
            cur.next = l1; l1 = l1.next
        else:
            cur.next = l2; l2 = l2.next
        cur = cur.next
    cur.next = l1 or l2
    return dummy.next''',
      cppSolution: '''ListNode* mergeTwoLists(ListNode* l1, ListNode* l2) {
    ListNode dummy(0);
    ListNode* cur = &dummy;
    while (l1 && l2) {
        if (l1->val < l2->val) { cur->next = l1; l1 = l1->next; }
        else { cur->next = l2; l2 = l2->next; }
        cur = cur->next;
    }
    cur->next = l1 ? l1 : l2;
    return dummy.next;
}''',
    ),
  ];

  /// Returns today's curated DSA challenge.
  DsaProblem getTodayProblem() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return _problemBank[dayOfYear % _problemBank.length];
  }
}
