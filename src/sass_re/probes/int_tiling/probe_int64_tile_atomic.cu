
// INT64 atomic add (compare with INT32 atomic throughput)
extern "C" __global__ void __launch_bounds__(128)
int64_atomic(unsigned long long *counter, int iters) {
    for(int j=0;j<iters;j++) atomicAdd(counter,1ULL);
}
