
// double2 atomic accumulation via 2 independent CAS loops
extern "C" __global__ void __launch_bounds__(128)
edge_d2_cas(double *out, const double2 *in, int n) {
    __shared__ double sx, sy;
    if(threadIdx.x==0){sx=0;sy=0;}
    __syncthreads();
    int gi=blockIdx.x*blockDim.x+threadIdx.x;
    if(gi<n){
        double2 v=in[gi];
        // CAS-add for x
        unsigned long long *ax=(unsigned long long*)&sx;
        unsigned long long old_x=*ax, assumed_x;
        do{assumed_x=old_x;old_x=atomicCAS(ax,assumed_x,__double_as_longlong(__longlong_as_double(assumed_x)+v.x));}while(assumed_x!=old_x);
        // CAS-add for y
        unsigned long long *ay=(unsigned long long*)&sy;
        unsigned long long old_y=*ay, assumed_y;
        do{assumed_y=old_y;old_y=atomicCAS(ay,assumed_y,__double_as_longlong(__longlong_as_double(assumed_y)+v.y));}while(assumed_y!=old_y);
    }
    __syncthreads();
    if(threadIdx.x==0){
        unsigned long long *gx=(unsigned long long*)&out[0], *gy=(unsigned long long*)&out[1];
        unsigned long long o,a;
        o=*gx;do{a=o;o=atomicCAS(gx,a,__double_as_longlong(__longlong_as_double(a)+sx));}while(a!=o);
        o=*gy;do{a=o;o=atomicCAS(gy,a,__double_as_longlong(__longlong_as_double(a)+sy));}while(a!=o);
    }
}
