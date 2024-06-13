class LinearCongruentialGenerator {
  final BigInt _a = BigInt.parse('6364136223846793005');
  final BigInt _c = BigInt.one;
  final BigInt _m = BigInt.from(1) << 32;
  BigInt _seed;

  LinearCongruentialGenerator(int seed) : _seed = BigInt.from(seed);

  int nextInt() {
    _seed = (_a * _seed + _c) % _m;
    return _seed.toInt();
  }

  double nextDouble() {
    return nextInt() / _m.toDouble();
  }
}