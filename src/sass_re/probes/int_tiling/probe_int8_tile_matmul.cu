
// INT8 naive matmul (no TC, pure IMAD path)
extern "C" __global__ void __launch_bounds__(128)
int8_matmul(int *C, const signed char *A, const signed char *B, int M, int N, int K) {
    int row=blockIdx.y*blockDim.y+threadIdx.y;
    int col=blockIdx.x*blockDim.x+threadIdx.x;
    if(row>=M||col>=N)return;
    int acc=0;
    for(int k=0;k<K;k++) acc+=(int)A[row*K+k]*(int)B[k*N+col];
    C[row*N+col]=acc;
}
