/// Diagnostic Assessment Questions for Mathalino Student App
/// 
/// This file contains the 20-item diagnostic assessment used for student placement,
/// sourced directly from Mathalino_Levels_1-20_100_Visual_ChildFriendly (1).docx.
/// 
/// Competency codes:
/// - M1NS: Grade 1 Number Sense (Count, recognize, and compare numbers 1-10)
/// - M2NS: Grade 2 Number Sense (Place value, skip counting, numbers to 100)
/// - M3NS: Grade 3 Number Sense (Three-digit place value, skip counting patterns)
/// - M2OP: Grade 2 Operations (Addition and subtraction of 1-2 digit numbers)
/// - M3OP: Grade 3 Operations (Multi-digit operations, multiplication, division)
library;

const List<Map<String, dynamic>> diagnosticAssessmentQuestions = [
  // Question 1 - M1NS: Represent and match quantities with number symbols (1-10)
  {
    'id': 'diag_001',
    'grade': 1,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M1NS',
    'competencyText': 'Represent and match quantities with number symbols (1-10)',
    'cognitiveDomain': 'Knowing',
    'type': 'multipleChoice',
    'questionText': 'Which picture shows 2?',
    'choices': ['A. ●', 'B. ● ●', 'C. ● ● ●', 'D. ● ● ● ●'],
    'correctAnswer': ['B', 'B. ● ●'],
    'maxPoints': 1,
    'explanation': 'Group B has exactly 2 dots (● ●).',
  },

  // Question 2 - M1NS: Counting sequence (What comes after 4?)
  {
    'id': 'diag_002',
    'grade': 1,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M1NS',
    'competencyText': 'Identify the number that comes next in a counting sequence',
    'cognitiveDomain': 'Knowing',
    'type': 'multipleChoice',
    'questionText': 'What number comes after 4?',
    'choices': ['A. 3', 'B. 4', 'C. 5', 'D. 6'],
    'correctAnswer': ['C', 'C. 5'],
    'maxPoints': 1,
    'explanation': 'Counting in order: 1, 2, 3, 4, 5. The number after 4 is 5.',
  },

  // Question 3 - M2NS: Skip counting by 2s
  {
    'id': 'diag_003',
    'grade': 2,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M2NS',
    'competencyText': 'Skip count by 2s and complete the pattern',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'Which number comes next? 2, 4, 6, ___',
    'choices': ['A. 7', 'B. 8', 'C. 9', 'D. 10'],
    'correctAnswer': ['B', 'B. 8'],
    'maxPoints': 1,
    'explanation': 'Skip counting by 2s: 2, 4, 6, 8. Adding 2 to 6 gives 8.',
  },

  // Question 4 - M1NS: Counting sequence (What comes before 7?)
  {
    'id': 'diag_004',
    'grade': 1,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M1NS',
    'competencyText': 'Identify the number that comes before in a counting sequence',
    'cognitiveDomain': 'Knowing',
    'type': 'multipleChoice',
    'questionText': 'What number comes BEFORE 7?',
    'choices': ['A. 5', 'B. 6', 'C. 7', 'D. 8'],
    'correctAnswer': ['B', 'B. 6'],
    'maxPoints': 1,
    'explanation': 'Counting in order: 5, 6, 7. The number immediately before 7 is 6.',
  },

  // Question 5 - M2NS: Place value (tens and ones)
  {
    'id': 'diag_005',
    'grade': 2,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M2NS',
    'competencyText': 'Understand place value (tens and ones)',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'In the number 74, what is the value of 7?',
    'choices': ['A. 7', 'B. 70', 'C. 700', 'D. 4'],
    'correctAnswer': ['B', 'B. 70'],
    'maxPoints': 1,
    'explanation': 'In 74, the digit 7 is in the tens place, so its value is 7 tens or 70.',
  },

  // Question 6 - M2OP: Addition (sums up to 10)
  {
    'id': 'diag_006',
    'grade': 2,
    'contentDomain': 'Operations',
    'competencyCode': 'M2OP',
    'competencyText': 'Add two single-digit numbers (sums up to 10)',
    'cognitiveDomain': 'Applying',
    'type': 'multipleChoice',
    'questionText': 'What is 3 + 2?',
    'choices': ['A. 4', 'B. 5', 'C. 6', 'D. 7'],
    'correctAnswer': ['B', 'B. 5'],
    'maxPoints': 1,
    'explanation': 'Adding 3 and 2 gives 5.',
  },

  // Question 7 - M1NS: Comparing visual quantities (more)
  {
    'id': 'diag_007',
    'grade': 1,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M1NS',
    'competencyText': 'Compare quantities using visual representation (more and fewer)',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'Which group has MORE?',
    'choices': ['A. ● ●', 'B. ● ● ● ●', 'C. Same', 'D. 0'],
    'correctAnswer': ['B', 'B. ● ● ● ●'],
    'maxPoints': 1,
    'explanation': 'Group B has 4 dots (● ● ● ●) while Group A has 2 dots (● ●). 4 is more than 2.',
  },

  // Question 8 - M2OP: Subtraction from 10
  {
    'id': 'diag_008',
    'grade': 2,
    'contentDomain': 'Operations',
    'competencyCode': 'M2OP',
    'competencyText': 'Subtract single-digit numbers from 10',
    'cognitiveDomain': 'Applying',
    'type': 'multipleChoice',
    'questionText': 'What is 10 - 4?',
    'choices': ['A. 5', 'B. 6', 'C. 7', 'D. 8'],
    'correctAnswer': ['B', 'B. 6'],
    'maxPoints': 1,
    'explanation': '10 minus 4 equals 6.',
  },

  // Question 9 - M3NS: Skip count backward by 10s from 100
  {
    'id': 'diag_009',
    'grade': 3,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M3NS',
    'competencyText': 'Skip count backward by 10s from 100',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'Which number comes next? 100, 90, 80, ___',
    'choices': ['A. 60', 'B. 70', 'C. 75', 'D. 85'],
    'correctAnswer': ['B', 'B. 70'],
    'maxPoints': 1,
    'explanation': 'The numbers decrease by 10 each time: 100, 90, 80, 70.',
  },

  // Question 10 - M3OP: Addition with regrouping
  {
    'id': 'diag_010',
    'grade': 3,
    'contentDomain': 'Operations',
    'competencyCode': 'M3OP',
    'competencyText': 'Add two 2-digit numbers with regrouping',
    'cognitiveDomain': 'Applying',
    'type': 'multipleChoice',
    'questionText': 'What is 35 + 27?',
    'choices': ['A. 52', 'B. 62', 'C. 72', 'D. 82'],
    'correctAnswer': ['B', 'B. 62'],
    'maxPoints': 1,
    'explanation': '35 + 27: 5 + 7 = 12 (write 2, carry 1); 1 + 3 + 2 = 6. Result is 62.',
  },

  // Question 11 - M2NS: Skip count by 3s
  {
    'id': 'diag_011',
    'grade': 2,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M2NS',
    'competencyText': 'Skip count by 3s to complete a number pattern',
    'cognitiveDomain': 'Knowing',
    'type': 'multipleChoice',
    'questionText': 'Which number comes next? 3, 6, 9, 12, ___',
    'choices': ['A. 14', 'B. 15', 'C. 16', 'D. 18'],
    'correctAnswer': ['B', 'B. 15'],
    'maxPoints': 1,
    'explanation': 'Skip counting by 3s: 3, 6, 9, 12, 15. Adding 3 to 12 gives 15.',
  },

  // Question 12 - M3OP: Multiplication using equal groups
  {
    'id': 'diag_012',
    'grade': 3,
    'contentDomain': 'Operations',
    'competencyCode': 'M3OP',
    'competencyText': 'Multiply using equal groups',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': '3 bags have 4 oranges each. How many oranges are there in total?',
    'choices': ['A. 7', 'B. 10', 'C. 12', 'D. 14'],
    'correctAnswer': ['C', 'C. 12'],
    'maxPoints': 1,
    'explanation': '3 groups of 4 oranges is 3 × 4 = 12 oranges.',
  },

  // Question 13 - M2OP: Addition beyond 10
  {
    'id': 'diag_013',
    'grade': 2,
    'contentDomain': 'Operations',
    'competencyCode': 'M2OP',
    'competencyText': 'Add two single-digit numbers with sums beyond 10',
    'cognitiveDomain': 'Applying',
    'type': 'multipleChoice',
    'questionText': 'What is 7 + 8?',
    'choices': ['A. 13', 'B. 14', 'C. 15', 'D. 16'],
    'correctAnswer': ['C', 'C. 15'],
    'maxPoints': 1,
    'explanation': '7 + 8 = 15.',
  },

  // Question 14 - M3NS: Skip count by 5s to 50
  {
    'id': 'diag_014',
    'grade': 3,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M3NS',
    'competencyText': 'Skip count by 5s to 50',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'Which number comes next? 5, 10, 15, 20, ___',
    'choices': ['A. 22', 'B. 24', 'C. 25', 'D. 30'],
    'correctAnswer': ['C', 'C. 25'],
    'maxPoints': 1,
    'explanation': 'Skip counting by 5s: 5, 10, 15, 20, 25.',
  },

  // Question 15 - M3OP: Division by sharing equally
  {
    'id': 'diag_015',
    'grade': 3,
    'contentDomain': 'Operations',
    'competencyCode': 'M3OP',
    'competencyText': 'Divide by sharing equally into groups',
    'cognitiveDomain': 'Applying',
    'type': 'multipleChoice',
    'questionText': '8 candies are shared equally between 2 children. How many candies does each child get?',
    'choices': ['A. 2', 'B. 3', 'C. 4', 'D. 5'],
    'correctAnswer': ['C', 'C. 4'],
    'maxPoints': 1,
    'explanation': '8 divided equally by 2 children is 8 ÷ 2 = 4 candies each.',
  },

  // Question 16 - M2NS: Fractions (one half)
  {
    'id': 'diag_016',
    'grade': 2,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M2NS',
    'competencyText': 'Identify fractional parts of a whole (one half)',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'Which fraction means ONE HALF?',
    'choices': ['A. 1/3', 'B. 1/2', 'C. 1/4', 'D. 2/3'],
    'correctAnswer': ['B', 'B. 1/2'],
    'maxPoints': 1,
    'explanation': 'One half is written as 1/2, representing 1 out of 2 equal parts.',
  },

  // Question 17 - M3OP: Subtraction with regrouping
  {
    'id': 'diag_017',
    'grade': 3,
    'contentDomain': 'Operations',
    'competencyCode': 'M3OP',
    'competencyText': 'Subtract 2-digit numbers with regrouping',
    'cognitiveDomain': 'Applying',
    'type': 'multipleChoice',
    'questionText': 'What is 60 - 25?',
    'choices': ['A. 25', 'B. 30', 'C. 35', 'D. 40'],
    'correctAnswer': ['C', 'C. 35'],
    'maxPoints': 1,
    'explanation': '60 - 25 = 35.',
  },

  // Question 18 - M2OP: Subtraction with bridging 10
  {
    'id': 'diag_018',
    'grade': 2,
    'contentDomain': 'Operations',
    'competencyCode': 'M2OP',
    'competencyText': 'Subtract single-digit numbers with bridging 10',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'What is 18 - 9?',
    'choices': ['A. 7', 'B. 8', 'C. 9', 'D. 10'],
    'correctAnswer': ['C', 'C. 9'],
    'maxPoints': 1,
    'explanation': '18 - 9 = 9.',
  },

  // Question 19 - M3NS: Skip count by 5s beyond 50
  {
    'id': 'diag_019',
    'grade': 3,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M3NS',
    'competencyText': 'Skip count by 5s beyond 50',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'Which number comes next? 50, 55, 60, 65, ___',
    'choices': ['A. 68', 'B. 70', 'C. 75', 'D. 80'],
    'correctAnswer': ['B', 'B. 70'],
    'maxPoints': 1,
    'explanation': 'The pattern adds 5 each time: 50, 55, 60, 65, 70.',
  },

  // Question 20 - M3OP: Multi-step word problem
  {
    'id': 'diag_020',
    'grade': 3,
    'contentDomain': 'Operations',
    'competencyCode': 'M3OP',
    'competencyText': 'Solve two-step word problems involving multiplication and subtraction',
    'cognitiveDomain': 'Analyzing',
    'type': 'multipleChoice',
    'questionText': '8 boxes have 6 pencils each. 5 pencils are used. How many pencils are left?',
    'choices': ['A. 43', 'B. 48', 'C. 53', 'D. 58'],
    'correctAnswer': ['A', 'A. 43'],
    'maxPoints': 1,
    'explanation': 'First find the total pencils: 8 × 6 = 48. Then subtract the used pencils: 48 − 5 = 43 pencils left.',
  },
];

/// Classification rules for student placement based on diagnostic performance
const Map<String, dynamic> placementRules = {
  'beginner': {
    'minPercentage': 0,
    'maxPercentage': 50,
    'category': 'Beginner',
    'startingLevel': 1,
    'contentPools': ['Grade 1', 'Grade 2', 'Grade 3'],
    'contentPoolLabel': 'Grade 1-3',
    'description': 'Foundational numeracy skills - needs strong support',
  },
  'intermediate': {
    'minPercentage': 50,
    'maxPercentage': 75,
    'category': 'Intermediate',
    'startingLevel': 21,
    'contentPools': ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'],
    'contentPoolLabel': 'Grade 1-6 Shuffled',
    'description': 'Core numeracy skills - progressing well',
  },
  'advanced': {
    'minPercentage': 75,
    'maxPercentage': 100,
    'category': 'Advanced',
    'startingLevel': 41,
    'contentPools': ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'],
    'contentPoolLabel': 'Grade 1-6 Advanced',
    'description': 'Strong numeracy foundation - ready for challenges',
  },
  'mastery': {
    'minPercentage': 100,
    'maxPercentage': 100,
    'category': 'Mastery',
    'startingLevel': 41,
    'contentPools': ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6 Advanced'],
    'contentPoolLabel': 'Grade 1-6 Advanced Full',
    'description': 'Mastered core skills - accelerated pathway',
  },
};

/// Competency framework for tracking and analysis
const Map<String, String> competencyDescriptions = {
  'M1NS': 'Grade 1 Number Sense: Count, recognize, and compare numbers 1-10',
  'M2NS': 'Grade 2 Number Sense: Place value, skip counting, numbers to 100',
  'M3NS': 'Grade 3 Number Sense: Three-digit place value, skip counting patterns',
  'M2OP': 'Grade 2 Operations: Addition and subtraction of 1-2 digit numbers',
  'M3OP': 'Grade 3 Operations: Multi-digit operations, multiplication, division',
};
