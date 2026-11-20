final _thousandsBoundary = RegExp(r'\B(?=(\d{3})+(?!\d))');

String groupedNumber(int number) => number.toString().replaceAll(_thousandsBoundary, ',');

String postDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}';
}
