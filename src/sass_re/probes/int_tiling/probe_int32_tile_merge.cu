
// INT32 merge (sorted merge of two arrays)
extern "C" __global__ void __launch_bounds__(128)
int32_merge(int *out, const int *a, int na, const int *b, int nb) {
    int tid=threadIdx.x+blockIdx.x*blockDim.x;
    int total=na+nb;
    if(tid>=total)return;
    // Binary search to find merge position
    int lo=max(0,tid-nb), hi=min(tid,na);
    while(lo<hi){int mid=(lo+hi)/2;if(a[mid]<b[tid-mid-1])lo=mid+1;else hi=mid;}
    int ai=lo, bi=tid-lo;
    out[tid]=(bi>=nb||(ai<na&&a[ai]<=b[bi]))?a[ai]:b[bi];
}
