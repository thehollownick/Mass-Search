#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <windows.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <time.h>
#include <ctime>

//calculating working hours
double PCFreq = 0.0;
__int64 CounterStart = 0;

void StartCounter()
{
	LARGE_INTEGER li;
	if (!QueryPerformanceFrequency(&li))
		std::cout << "QueryPerformanceFrequency failed!\n";

	PCFreq = double(li.QuadPart) / 1000.0;

	QueryPerformanceCounter(&li);
	CounterStart = li.QuadPart;
}
double GetCounter()
{
	LARGE_INTEGER li;
	QueryPerformanceCounter(&li);
	return double(li.QuadPart - CounterStart) / PCFreq;
}

__global__ void parallelGrep(char* global_data, int globalData_Size, char* key, int key_size, int* key_indexes, int* curr_index)
{
	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	int key0 = key[0];

	if (idx < globalData_Size)
	{
		if (global_data[idx] == key0)
		{
			int save = 1;

			for (int i = 1; i < key_size; i++)
			{
				if (global_data[idx + i] != key[i])
				{
					save = 0;
					break;
				}
			}
			if (save == 1)
			{
				key_indexes[atomicAdd(curr_index, 1)] = idx;
			}
		}
	}

}

int SubStrCount(const char* str, const char* subStr)
{
	int res = 0, len;
	if (str && subStr)
	{
		if (len = strlen(subStr))
		{
			for (char const* p = str; *p; p += strncmp(p, subStr, len) ? 1 : (++res, len))
				;
		}
	}
	return res;
}

int main()
{
	FILE* file;
	size_t numB;
	long lSize;
	size_t key_size, key_ind_size;
	char* data_d, *data_h, *key_d;
	char key_h[50];
	int key_ind_h[600];
	int* key_ind_d;
	int currind;
	int* curr_ind_h = &currind;
	int* curr_ind_d;


	file = fopen("text.txt", "rb");
	if (file == NULL)
	{
		printf("Cannot open txt file!\n");
		exit(1);
	}
	fseek(file, 0, SEEK_END);
	lSize = ftell(file);
	rewind(file);

	data_h = new char[lSize];	//  memory on host
	cudaMalloc((void**)&data_d, lSize);	//  memory on device	



	numB = fread(data_h, 1, lSize, file); //read from file
	cudaMemcpy(data_d, data_h, lSize, cudaMemcpyHostToDevice);	// copy data to device memory

	strcpy(key_h, "can"); //substring
	key_size = strlen(key_h);

	cudaMalloc((void**)&key_d, key_size);
	cudaMemcpy(key_d, key_h, key_size, cudaMemcpyHostToDevice); // copy substring to device memory

	//buff
	key_ind_size = sizeof(key_ind_h);
	memset(key_ind_h, 0, key_ind_size);
	cudaMalloc((void**)&key_ind_d, key_ind_size);
	cudaMemcpy(key_ind_d, key_ind_h, key_ind_size, cudaMemcpyHostToDevice);

	*curr_ind_h = 0;
	cudaMalloc((void**)&curr_ind_d, 4);
	cudaMemcpy(curr_ind_d, curr_ind_h, 4, cudaMemcpyHostToDevice);


	int block_size = 1024;
	int n_blocks = lSize / block_size + (lSize % block_size == 0 ? 0 : 1);

	///////////////////////////////////
	StartCounter();

	parallelGrep << < n_blocks, block_size >> > (data_d, lSize, key_d, key_size, key_ind_d, curr_ind_d);


	cudaMemcpy(key_ind_h, key_ind_d, key_ind_size, cudaMemcpyDeviceToHost);

	printf("Time GPU ");
	std::cout << GetCounter() << " ms" << std::endl;


	int pIter = 0;
	while (key_ind_h[pIter] != 0)
	{
		pIter++;
	}
	printf("%d", pIter);
	printf("%c", '\n');
	////host
	clock_t start = clock();
	int count = SubStrCount(data_h, key_h);
	printf("Time CPU = %lf ms\n", (long double)(clock() - start) / CLOCKS_PER_SEC * 1000);

	printf("%d", count);


	delete[] data_h;
	cudaFree(data_d);
	cudaFree(key_d);
	cudaFree(key_ind_d);
	cudaFree(curr_ind_d);
	return 0;
}
