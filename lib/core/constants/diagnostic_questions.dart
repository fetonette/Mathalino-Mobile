/// Diagnostic Assessment Questions for Mathalino Student App
/// 
/// This file contains the 20-item RMA-adapted diagnostic assessment used for
/// student placement. Questions cover foundational numeracy competencies
/// from Grades 1-3 aligned to Philippine K-12 curriculum.
/// 
/// Competency codes:
/// - M1NS: Grade 1 Number Sense
/// - M2NS: Grade 2 Number Sense
/// - M3NS: Grade 3 Number Sense
/// - M2OP: Grade 2 Operations
/// - M3OP: Grade 3 Operations
library;

const List<Map<String, dynamic>> diagnosticAssessmentQuestions = [
  // Question 1 - M1NS: Count objects to 10
  {
    'id': 'diag_001',
    'grade': 1,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M1NS',
    'competencyText': 'Count objects to 10 and identify the quantity',
    'cognitiveDomain': 'Knowing',
    'type': 'numericInput',
    'questionText': 'How many stars are shown? ⭐⭐⭐⭐⭐',
    'correctAnswer': '5',
    'maxPoints': 1,
  },
  
  // Question 2 - M1NS: Number recognition 1-10
  {
    'id': 'diag_002',
    'grade': 1,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M1NS',
    'competencyText': 'Recognize and write numbers 1 to 10',
    'cognitiveDomain': 'Knowing',
    'type': 'numericInput',
    'questionText': 'Write the number that comes after 7.',
    'correctAnswer': '8',
    'maxPoints': 1,
  },
  
  // Question 3 - M2NS: Skip counting by 2s
  {
    'id': 'diag_003',
    'grade': 2,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M2NS',
    'competencyText': 'Skip count by 2s, 5s, and 10s',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'Which number comes next? 2, 4, 6, 8, ___',
    'choices': ['A. 9', 'B. 10', 'C. 11', 'D. 12'],
    'correctAnswer': ['B', 'B. 10'],
    'maxPoints': 1,
  },
  
  // Question 4 - M1NS: One-to-one correspondence
  {
    'id': 'diag_004',
    'grade': 1,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M1NS',
    'competencyText': 'Match quantity to numeral (1-10)',
    'cognitiveDomain': 'Applying',
    'type': 'numericInput',
    'questionText': 'There are 3 apples and 5 oranges. How many fruits in total?',
    'correctAnswer': '8',
    'maxPoints': 1,
  },
  
  // Question 5 - M2NS: Place value tens and ones
  {
    'id': 'diag_005',
    'grade': 2,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M2NS',
    'competencyText': 'Understand place value (tens and ones)',
    'cognitiveDomain': 'Understanding',
    'type': 'numericInput',
    'questionText': 'In the number 24, how many tens are there?',
    'correctAnswer': '2',
    'maxPoints': 1,
  },
  
  // Question 6 - M2OP: Simple addition (sums to 10)
  {
    'id': 'diag_006',
    'grade': 2,
    'contentDomain': 'Operations',
    'competencyCode': 'M2OP',
    'competencyText': 'Add two single-digit numbers (sums to 10)',
    'cognitiveDomain': 'Applying',
    'type': 'numericInput',
    'questionText': 'What is 3 + 4?',
    'correctAnswer': '7',
    'maxPoints': 1,
  },
  
  // Question 7 - M1NS: Comparing numbers 1-10
  {
    'id': 'diag_007',
    'grade': 1,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M1NS',
    'competencyText': 'Compare quantities using more, less, equal',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'Which group has MORE? A group of 4 cats or a group of 7 dogs?',
    'choices': ['A. 4 cats', 'B. 7 dogs', 'C. They are equal', 'D. Cannot tell'],
    'correctAnswer': ['B', 'B. 7 dogs'],
    'maxPoints': 1,
  },
  
  // Question 8 - M2OP: Subtraction (from 10)
  {
    'id': 'diag_008',
    'grade': 2,
    'contentDomain': 'Operations',
    'competencyCode': 'M2OP',
    'competencyText': 'Subtract single-digit numbers from 10',
    'cognitiveDomain': 'Applying',
    'type': 'numericInput',
    'questionText': 'What is 10 - 3?',
    'correctAnswer': '7',
    'maxPoints': 1,
  },
  
  // Question 9 - M3NS: Three-digit numbers place value
  {
    'id': 'diag_009',
    'grade': 3,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M3NS',
    'competencyText': 'Identify place value in 3-digit numbers (hundreds)',
    'cognitiveDomain': 'Understanding',
    'type': 'numericInput',
    'questionText': 'In the number 256, what digit is in the hundreds place?',
    'correctAnswer': '2',
    'maxPoints': 1,
  },
  
  // Question 10 - M3OP: Addition with regrouping
  {
    'id': 'diag_010',
    'grade': 3,
    'contentDomain': 'Operations',
    'competencyCode': 'M3OP',
    'competencyText': 'Add two 2-digit numbers with regrouping',
    'cognitiveDomain': 'Applying',
    'type': 'numericInput',
    'questionText': 'What is 24 + 18?',
    'correctAnswer': '42',
    'maxPoints': 1,
  },
  
  // Question 11 - M2NS: Number sequence 11-20
  {
    'id': 'diag_011',
    'grade': 2,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M2NS',
    'competencyText': 'Recognize numbers 11-20 and order',
    'cognitiveDomain': 'Knowing',
    'type': 'multipleChoice',
    'questionText': 'Which number is between 14 and 18?',
    'choices': ['A. 12', 'B. 16', 'C. 20', 'D. 22'],
    'correctAnswer': ['B', 'B. 16'],
    'maxPoints': 1,
  },
  
  // Question 12 - M3OP: Multiplication as repeated addition
  {
    'id': 'diag_012',
    'grade': 3,
    'contentDomain': 'Operations',
    'competencyCode': 'M3OP',
    'competencyText': 'Multiply using repeated addition (2 × 3)',
    'cognitiveDomain': 'Understanding',
    'type': 'numericInput',
    'questionText': 'There are 3 groups of 4 pencils. How many pencils in total?',
    'correctAnswer': '12',
    'maxPoints': 1,
  },
  
  // Question 13 - M2OP: Addition beyond 10
  {
    'id': 'diag_013',
    'grade': 2,
    'contentDomain': 'Operations',
    'competencyCode': 'M2OP',
    'competencyText': 'Add two single-digit numbers (sums beyond 10)',
    'cognitiveDomain': 'Applying',
    'type': 'numericInput',
    'questionText': 'What is 7 + 5?',
    'correctAnswer': '12',
    'maxPoints': 1,
  },
  
  // Question 14 - M3NS: Counting by 5s to 50
  {
    'id': 'diag_014',
    'grade': 3,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M3NS',
    'competencyText': 'Skip count by 5s to 50',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'What number comes next? 5, 10, 15, 20, ___',
    'choices': ['A. 22', 'B. 25', 'C. 30', 'D. 35'],
    'correctAnswer': ['B', 'B. 25'],
    'maxPoints': 1,
  },
  
  // Question 15 - M3OP: Division (sharing equally)
  {
    'id': 'diag_015',
    'grade': 3,
    'contentDomain': 'Operations',
    'competencyCode': 'M3OP',
    'competencyText': 'Divide by sharing equally (12 ÷ 3)',
    'cognitiveDomain': 'Applying',
    'type': 'numericInput',
    'questionText': 'If you have 12 candies and share them equally among 3 friends, how many does each friend get?',
    'correctAnswer': '4',
    'maxPoints': 1,
  },
  
  // Question 16 - M2NS: Ordering numbers to 50
  {
    'id': 'diag_016',
    'grade': 2,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M2NS',
    'competencyText': 'Order numbers up to 50',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'Which set shows numbers in order from smallest to largest?',
    'choices': ['A. 32, 23, 35', 'B. 23, 32, 35', 'C. 35, 32, 23', 'D. 32, 35, 23'],
    'correctAnswer': ['B', 'B. 23, 32, 35'],
    'maxPoints': 1,
  },
  
  // Question 17 - M3OP: Subtraction with regrouping
  {
    'id': 'diag_017',
    'grade': 3,
    'contentDomain': 'Operations',
    'competencyCode': 'M3OP',
    'competencyText': 'Subtract two 2-digit numbers with regrouping',
    'cognitiveDomain': 'Applying',
    'type': 'numericInput',
    'questionText': 'What is 35 - 18?',
    'correctAnswer': '17',
    'maxPoints': 1,
  },
  
  // Question 18 - M2OP: Number bonds to 10
  {
    'id': 'diag_018',
    'grade': 2,
    'contentDomain': 'Operations',
    'competencyCode': 'M2OP',
    'competencyText': 'Identify number pairs that make 10',
    'cognitiveDomain': 'Understanding',
    'type': 'numericInput',
    'questionText': 'What number should go with 6 to make 10?',
    'correctAnswer': '4',
    'maxPoints': 1,
  },
  
  // Question 19 - M3NS: Skip count by 10s to 100
  {
    'id': 'diag_019',
    'grade': 3,
    'contentDomain': 'Number Sense',
    'competencyCode': 'M3NS',
    'competencyText': 'Skip count by 10s to 100',
    'cognitiveDomain': 'Understanding',
    'type': 'multipleChoice',
    'questionText': 'What number comes next? 10, 20, 30, 40, ___',
    'choices': ['A. 41', 'B. 45', 'C. 50', 'D. 60'],
    'correctAnswer': ['C', 'C. 50'],
    'maxPoints': 1,
  },
  
  // Question 20 - M3OP: Word problem with addition
  {
    'id': 'diag_020',
    'grade': 3,
    'contentDomain': 'Operations',
    'competencyCode': 'M3OP',
    'competencyText': 'Solve word problems using addition',
    'cognitiveDomain': 'Analyzing',
    'type': 'numericInput',
    'questionText': 'Maria has 15 stickers. Her friend gave her 12 more stickers. How many stickers does Maria have now?',
    'correctAnswer': '27',
    'maxPoints': 1,
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
