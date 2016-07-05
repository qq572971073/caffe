#ifndef __OPENCL_VERSION__
#include "header.cl"
#endif
#define VEC_SIZE 4
__kernel void TEMPLATE(matvec_mul4,Dtype)( 
          __global const float4 * A, 
          unsigned int A_col_size, 
          __global const float4 * v, 
          __global float4 * result, 
          __local float4 * work) 
{
  A_col_size /= VEC_SIZE;
 
  unsigned int row_gid = get_group_id(0); 
  unsigned int lid = get_local_id(0);
  const __global float4 *src0_read = A + row_gid * 4 * A_col_size;
  const __global float4 *src1_read = v;
  float4 dot0 = (float4)(0.f);
  float4 dot1 = (float4)(0.f);
  float4 dot2 = (float4)(0.f);
  float4 dot3 = (float4)(0.f);
  //float4 dot4 = (float4)(0.f);
  //float4 dot5 = (float4)(0.f);
  //float4 dot6 = (float4)(0.f);
  //float4 dot7 = (float4)(0.f);

  unsigned int i = lid;
  do
  {
    const float4 a0 = src0_read[i];
    const float4 a1 = src0_read[i + A_col_size];
    const float4 a2 = src0_read[i + 2 * A_col_size];
    const float4 a3 = src0_read[i + 3 * A_col_size];
    //const float4 a4 = src0_read[i + 4 * A_col_size];
    //const float4 a5 = src0_read[i + 5 *A_col_size];
    //const float4 a6 = src0_read[i + 6 * A_col_size];
    //const float4 a7 = src0_read[i + 7 * A_col_size];

    const float4 b0 = src1_read[i];

    dot0 += a0 * b0;
    dot1 += a1 * b0;
    dot2 += a2 * b0;
    dot3 += a3 * b0;
    //dot4 += a4 * b0;
    //dot5 += a5 * b0;
    //dot6 += a6 * b0;
    //dot7 += a7 * b0;
    i += get_local_size(0);  
  }
  while( i < A_col_size);

  work[lid].s0 = dot0.x + dot0.y + dot0.z + dot0.w;
  work[lid].s1 = dot1.x + dot1.y + dot1.z + dot1.w;
  work[lid].s2 = dot2.x + dot2.y + dot2.z + dot2.w;
  work[lid].s3 = dot3.x + dot3.y + dot3.z + dot3.w;
  //work[lid].s4 = dot4.x + dot4.y + dot4.z + dot4.w;
  //work[lid].s5 = dot5.x + dot5.y + dot5.z + dot5.w;
  //work[lid].s6 = dot6.x + dot6.y + dot6.z + dot6.w;
  //work[lid].s7 = dot7.x + dot7.y + dot7.z + dot7.w;
  //printf("work[0] = %f \t", work[0]);
  for(unsigned int stride=get_local_size(0)/2 ; stride>0 ; stride>>=1) { 
      barrier(CLK_LOCAL_MEM_FENCE); 
      if(lid < stride) 
        work[lid] += work[lid+stride]; 
  }
  if(lid == 0)
    result[row_gid] = work[0];
}

__kernel void TEMPLATE(matvec_mul1,Dtype)( 
          __global const float4 * A, 
          unsigned int A_col_size, 
          unsigned int row_offset,
          __global const float4 * v, 
          __global float * result, 
          __local float * work) 
{
  A_col_size /= VEC_SIZE;
 
  unsigned int row_gid = get_group_id(0); 
  unsigned int lid = get_local_id(0);

  const __global float4 *src0_read = A + (row_offset + row_gid) * A_col_size;
  const __global float4 *src1_read = v;
  float4 dot0 = (float4)(0.f);

  unsigned int i = lid;
  do
  {
    const float4 a0 = src0_read[i];
    const float4 b0 = src1_read[i];

    dot0 += a0 * b0;
    i += get_local_size(0);  
  }
  while( i < A_col_size);

  work[lid] = dot0.x + dot0.y + dot0.z + dot0.w;
  for(unsigned int stride=get_local_size(0)/2 ; stride>0 ; stride>>=1) { 
      barrier(CLK_LOCAL_MEM_FENCE); 
      if(lid < stride) 
        work[lid] += work[lid+stride]; 
  }

  if(lid == 0)
    result[row_gid+row_offset] = work[0];
}

__kernel void TEMPLATE(vec_mul,Dtype)( 
          __global const float4 * A, 
          unsigned int A_row_size, unsigned int A_col_size, 
          __global const float4 * v,  
          __global float * result, 
          __local float * work) 
{
  A_col_size /= 4; 
  unsigned int row_gid = get_group_id(0);
  unsigned int lid = get_local_id(0); 
  unsigned int row_stride = get_num_groups(0);
  unsigned int col_stride = get_local_size(0);
  for (unsigned int row = row_gid; row < A_row_size; row += row_stride) 
  { 
    float4 dot_prod = 0;
    float4 a_temp = 0;
    float4 v_temp = 0; 
    for (unsigned int col = lid; col < A_col_size; col+=col_stride){
      a_temp = A[row * A_col_size + col];
      v_temp = v[col]; 
      dot_prod += a_temp * v_temp;
    } 
    work[lid] = dot_prod.x + dot_prod.y + dot_prod.z + dot_prod.w; 
    for(unsigned int stride=get_local_size(0)/2 ; stride>0 ; stride>>=1){ 
      barrier(CLK_LOCAL_MEM_FENCE); 
      if(lid < stride) 
        work[lid] += work[lid+stride]; 
    } 
    if(lid == 0) 
      result[row] = work[0]; 
  }
}

__kernel void TEMPLATE(vec_mul1,Dtype)( 
          __global const float * A, 
          unsigned int A_row_size, unsigned int A_col_size, 
          __global const float * v,  
          __global float * result, 
          __local float * work) 
{

  unsigned int row_gid = get_global_id(0) / get_local_size(0);
  unsigned int col_gid = get_global_id(0) % get_local_size(0);
  unsigned int lid = get_local_id(0);
  
  float4 col_data[18];
  unsigned int row = row_gid;
    float4 dot_prod = 0;
    float4 a_temp = 0;
    unsigned int i = 0;
    for (unsigned int col = col_gid; col < A_col_size / 4; col+=get_local_size(0)){
      a_temp = vload4(col, A + row * A_col_size);
      col_data[i] = vload4(col_gid + i * get_local_size(0), v);
      dot_prod += a_temp * col_data[i];
      ++i;
    }
    work[lid] = dot(dot_prod, (float4)(1.0f, 1.0f, 1.0f, 1.0f));
    for(unsigned int stride=get_local_size(0)/2 ; stride>0 ; stride>>=1){
      barrier(CLK_LOCAL_MEM_FENCE);
      if(lid < stride)
        work[lid] += work[lid+stride];
    }
    if(lid == 0)
      result[row] = work[0];

  for (unsigned int row = row_gid + get_num_groups(0); row < A_row_size; row += get_num_groups(0))
  {
    float4 dot_prod = 0;
    float4 a_temp = 0;
    unsigned int i = 0;
    for (unsigned int col = col_gid; col < A_col_size / 4; col+=get_local_size(0)){
      a_temp = vload4(col, A + row * A_col_size);
      dot_prod += a_temp * col_data[i];
      ++i;
    }
    work[lid] = dot(dot_prod, (float4)(1.0f, 1.0f, 1.0f, 1.0f));
    for(unsigned int stride=get_local_size(0)/2 ; stride>0 ; stride>>=1){
      barrier(CLK_LOCAL_MEM_FENCE);
      if(lid < stride)
        work[lid] += work[lid+stride];
    }
    if(lid == 0)
      result[row] = work[0];
  }
} 
