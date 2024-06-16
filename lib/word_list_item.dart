//
// class WordListItem extends StatefulWidget {
//   final String word;
//   final bool animate;
//
//   WordListItem({required Key key, required this.word, required this.animate}) : super(key: key);
//
//   @override
//   _WordListItemState createState() => _WordListItemState();
// }
//
// class _WordListItemState extends State<WordListItem> with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _animation;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(seconds: 1),
//       vsync: this,
//     );
//     _animation = Tween<double>(begin: 1.0, end: 1.5).animate(_controller);
//
//     if (!widget.animate) {
//       _controller.stop();
//     }
//   }
//
//   @override
//   void didUpdateWidget(covariant WordListItem oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.animate && !_controller.isAnimating) {
//       _controller.repeat(reverse: true);
//     } else if (!widget.animate && _controller.isAnimating) {
//       _controller.stop();
//     }
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: widget.animate ? _animation.value : 1.0,
//           child: ListTile(
//             title: Text(widget.word),
//           ),
//         );
//       },
//     );
//   }
// }