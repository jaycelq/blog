---
layout: post
title: "STL 空间配置器"
date: 2015-04-29 14:51:57 +0800
comments: true
sharing: false
categories: [STL, C++]
---

最近在读侯捷老师的STL源码剖析，感觉自己的C++实在太菜，我准备写一个系列的读书笔记，从我的角度时如何读懂这本书的，重点说说书里没有提到和我觉得比较重要的，一方面督促自己把书看完，另外，博客也好久没更新了 囧= =！

第一篇谈一下stl中的内存配置器。

-------------------

<!-- more -->

## operator new和new operator
operator new 是一个函数，用来分配内存，它和malloc相似，用来分配对象的内存。函数签名为：
```
void *operator new(size_t);
```

```c++
char *x = static_cast<char *>(operator new(100));
```
	
在实现自己的容器时可以直接调用operator new 函数。也可以重写全局的或者某个类的operator new函数。当然如果你重写了operator new函数，一般也要相应的operator delete函数。

new operator是C++中的远算符表达式，也就是通常情况下我们使用的new操作。它和operator new函数的不同在于operator new函数只是分配内存，new 运算符还会调用构造函数。

另外，在使用new运算表达式，可能还会碰到placement new。使用这种placement new，原因之一是用户的程序不能在一块内存上自行调用其构造函数（即用户的程序不能显式调用构造函数），必须由编译系统生成的代码调用构造函数。原因之二是可能需要把对象放在特定硬件的内存地址上，或者放在多处理器内核的共享的内存地址上。释放这种对象时，不能调用placement delete，应直接调用析构函数，如：pObj->~ClassType();然后再自行释放内存。

不过如果调用placement你要负责保证指向的位置有足够的内存，编译器和运行时都不会去检查，如果你需要的对象4字节对齐，而你提供的空间没有四字节对齐，那么很可能会造成意想不到的灾难。
```
#include <iostream>
using namespace std;
 
int main(int argc, char* argv[])
{
    char buf[100];
    int *p=new (buf) int(101);
    cout<<*(int*)buf<<endl;
    return 0;
}
```

## STL中的内存配置过程

上面已经提到了new的过程包含两个阶段：(1) 调用::opeartor new配置内存；(2)调用构造函数构造对象。delete算是也包含两个阶段：(1)调用析构函数将对象析构；（2）调用::operator delete释放内存。

STL将两个阶段分开，内存配置由alloc::allocate()负责，释放由alloc::dealloc()负责；对象构造由::construct()负责，对象析构由::destroy()负责。

{% img fancybox /images/2015-04-29/STL_Alloc.png 500 %}

###构造和析构
构造过程如下：
```
template <class _T1, class _T2>
inline void _Construct(_T1* __p, const _T2& __value) {
  new ((void*) __p) _T1(__value);
}

template <class _T1>
inline void _Construct(_T1* __p) {
  new ((void*) __p) _T1();
}
```
构造过程调用上述的placement new运算符，生成的对象放在allocator分配的内存中。


析构过程如下：
```
template <class _Tp>
inline void _Destroy(_Tp* __pointer) {
  __pointer->~_Tp();
}
template <class _ForwardIterator>
void
__destroy_aux(_ForwardIterator __first, _ForwardIterator __last, __false_type)
{
  for ( ; __first != __last; ++__first)
    destroy(&*__first);
}

template <class _ForwardIterator> 
inline void __destroy_aux(_ForwardIterator, _ForwardIterator, __true_type) {}

template <class _ForwardIterator, class _Tp>
inline void 
__destroy(_ForwardIterator __first, _ForwardIterator __last, _Tp*)
{
  typedef typename __type_traits<_Tp>::has_trivial_destructor
          _Trivial_destructor;
  __destroy_aux(__first, __last, _Trivial_destructor());
}

template <class _ForwardIterator>
inline void _Destroy(_ForwardIterator __first, _ForwardIterator __last) {
  __destroy(__first, __last, __VALUE_TYPE(__first));
}

inline void _Destroy(char*, char*) {}
inline void _Destroy(int*, int*) {}
inline void _Destroy(long*, long*) {}
inline void _Destroy(float*, float*) {}
inline void _Destroy(double*, double*) {}
#ifdef __STL_HAS_WCHAR_T
inline void _Destroy(wchar_t*, wchar_t*) {}
#endif /* __STL_HAS_WCHAR_T */
```

析构函数有两个版本，第一个版本接受一个指针，直接调用对象对应的析构函数。第二个版本接受两个迭代器，接受两个迭代器，STL通过value_type()获得对象类型然后利用__type_traits\<T\>判断对象的析构是否为trivial，如果是true_type则什么都不用做，直接结束。若为false_type，则循环对每个对象调用destroy()。关于type_traits\<T\>会在以后的文章介绍，这里先大概理解一下。

###空间配置和释放
上面提到C++通过operator new分配内存，相当于进行系统调用malloc，而系统为了记录分配出去的内存，一定会有额外的开销，当分配的内存越小，这种开销相对越大，为此STL设计了二级空间配置器。

\__malloc_alloc_template 为第一级适配器， __default_alloc_template为第二级适配器。两级适配器都是通过simple_alloc一层封装实现调用的。

```
template<class _Tp, class _Alloc>
class simple_alloc {

public:
    static _Tp* allocate(size_t __n)
      { return 0 == __n ? 0 : (_Tp*) _Alloc::allocate(__n * sizeof (_Tp)); }
    static _Tp* allocate(void)
      { return (_Tp*) _Alloc::allocate(sizeof (_Tp)); }
    static void deallocate(_Tp* __p, size_t __n)
      { if (0 != __n) _Alloc::deallocate(__p, __n * sizeof (_Tp)); }
    static void deallocate(_Tp* __p)
      { _Alloc::deallocate(__p, sizeof (_Tp)); }
};
```
{% img fancybox /images/2015-04-29/two_allocator.png 500 %}

第一配置器和operator new相似，以malloc(), free(), realloc()配置、释放、重配置内存，并实现类似C++ new-handler的机制，即在operator new无法完成任务，抛出std::bad_alloc异常状态之前，会调用客户端的处理程序new-handler。SGI STL并非通过operator new来配置内存，因此不能直接使用C++的set_new_handler()，而是通过仿真的set_malloc_handler()。

第二级适配器维护了16个free-list，各自维护8，16 ... 128个字节大小的小额区块。节点结构如下：
```
union _Obj {
  union _Obj* _M_free_list_link;
    char _M_client_data[1];    /* The client sees this.        */
};
```
这样的链表设计非常精妙，首先作为一个链表，它要维护到下一个内存节点的指针，即_M_free_list_link，同时还要维护实际的空内存，即_M_client_data。采用union结构体，_M_free_list_link和_M_client_data占用同一块内存空间，可以减少维护链表所需要的额外空间。因为作为空内存，内存并未被使用，所以头部的四个字节用来链表的next。当内存被使用，_M_client_data作为实际空间返回，此时内存不属于空内存，不再属于free_list，因此指针不再需要。整个空间作为free内存返回。

{% img fancybox /images/2015-04-29/free_list.png 500 %}

####第二级适配器内存分配
第二级适配器内存分配（allocate）过程：

1. 如果空间大于_MAX_BYTES（128 bytes），调用第一级适配器malloc分配。

2. 否则从free_list数组中找到相应的free内存链

3. 若free_list对应的内存链中没有空闲内存，则调用refill分配后返回

4. 返回对应free_list链中的第一块空闲内存，将list指向下一个

```
  static void* allocate(size_t __n)
  {
    void* __ret = 0;

    if (__n > (size_t) _MAX_BYTES) {
      __ret = malloc_alloc::allocate(__n);
    }
    else {
      _Obj* __STL_VOLATILE* __my_free_list
          = _S_free_list + _S_freelist_index(__n);
      // Acquire the lock here with a constructor call.
      // This ensures that it is released in exit or during stack
      // unwinding.
#     ifndef _NOTHREADS
      /*REFERENCED*/
      _Lock __lock_instance;
#     endif
      _Obj* __RESTRICT __result = *__my_free_list;
      if (__result == 0)
        __ret = _S_refill(_S_round_up(__n));
      else {
        *__my_free_list = __result -> _M_free_list_link;
        __ret = __result;
      }
    }

    return __ret;
  };
```

refiill函数的执行过程：

1. 通过chunk_alloc获得nobjs个内存节点(缺省20个，可能小于20个)

2. 若nobjs刚好为1个，则直接返回内存地址

3. 若nobjs大于1个，则将后nobjs-1块内存链入free_list，将第一块地址返回

```
/* We hold the allocation lock.                                         */
template <bool __threads, int __inst>
void*
__default_alloc_template<__threads, __inst>::_S_refill(size_t __n)
{
    int __nobjs = 20;
    char* __chunk = _S_chunk_alloc(__n, __nobjs);
    _Obj* __STL_VOLATILE* __my_free_list;
    _Obj* __result;
    _Obj* __current_obj;
    _Obj* __next_obj;
    int __i;

    if (1 == __nobjs) return(__chunk);
    __my_free_list = _S_free_list + _S_freelist_index(__n);

    /* Build free list in chunk */
      __result = (_Obj*)__chunk;
      *__my_free_list = __next_obj = (_Obj*)(__chunk + __n);
      for (__i = 1; ; __i++) {
        __current_obj = __next_obj;
        __next_obj = (_Obj*)((char*)__next_obj + __n);
        if (__nobjs - 1 == __i) {
            __current_obj -> _M_free_list_link = 0;
            break;
        } else {
            __current_obj -> _M_free_list_link = __next_obj;
        }
      }
    return(__result);
}
```

chunk_alloc函数的执行过程：

1. 判断内存池中剩余的内存(bytes_left = end_free - start_free)是否足够，若足够，则start_free += total_bytes，并将原地址返回。 

2. 如果内存池中的剩余空闲内存不够全部空间，但大于一个区块的空间，则更新nobjs，start_free += total_bytes，并将原地址返回。 

3. 如果内存池中的剩余空闲内存连一个都不足，若剩余的空间大于0，则将剩余的空间放入相应的free_list链表中。（个人的理解，由于内存分配和使用的时候都是8的倍数，因此剩下的内存必然也是8的倍数，不会出现剩余的内存放入链表但不是8的倍数的情况。）

4. 通过malloc配置内存，返回地址为start_free，大小为2 * total_bytes + round_up(heap_size >> 4)，这里为什么要加heap_size >> 4四位我也不是特别清楚，可能分配的空间会满足一种规律。

5. 若malloc失败，则查找大于size的下几级free_list，从找到的free_list中拿出第一项，将start_free和start_end更新为相应的起始地址和终止地址，递归调用chunk_alloc并返回。

6. 如果free_list也没有空余的内存，则调用malloc_alloc::alloc，抛出异常。

7. 如果malloc成功，更新start_free, end_free，递归调用chunk_alloc并返回。
```
template <bool __threads, int __inst>
char*
__default_alloc_template<__threads, __inst>::_S_chunk_alloc(size_t __size, 
                                                            int& __nobjs)
{
    char* __result;
    size_t __total_bytes = __size * __nobjs;
    size_t __bytes_left = _S_end_free - _S_start_free;

    if (__bytes_left >= __total_bytes) {
        __result = _S_start_free;
        _S_start_free += __total_bytes;
        return(__result);
    } else if (__bytes_left >= __size) {
        __nobjs = (int)(__bytes_left/__size);
        __total_bytes = __size * __nobjs;
        __result = _S_start_free;
        _S_start_free += __total_bytes;
        return(__result);
    } else {
        size_t __bytes_to_get = 
    2 * __total_bytes + _S_round_up(_S_heap_size >> 4);
        // Try to make use of the left-over piece.
        if (__bytes_left > 0) {
            _Obj* __STL_VOLATILE* __my_free_list =
                        _S_free_list + _S_freelist_index(__bytes_left);

            ((_Obj*)_S_start_free) -> _M_free_list_link = *__my_free_list;
            *__my_free_list = (_Obj*)_S_start_free;
        }
        _S_start_free = (char*)malloc(__bytes_to_get);
        if (0 == _S_start_free) {
            size_t __i;
            _Obj* __STL_VOLATILE* __my_free_list;
      _Obj* __p;
            // Try to make do with what we have.  That can't
            // hurt.  We do not try smaller requests, since that tends
            // to result in disaster on multi-process machines.
            for (__i = __size;
                 __i <= (size_t) _MAX_BYTES;
                 __i += (size_t) _ALIGN) {
                __my_free_list = _S_free_list + _S_freelist_index(__i);
                __p = *__my_free_list;
                if (0 != __p) {
                    *__my_free_list = __p -> _M_free_list_link;
                    _S_start_free = (char*)__p;
                    _S_end_free = _S_start_free + __i;
                    return(_S_chunk_alloc(__size, __nobjs));
                    // Any leftover piece will eventually make it to the
                    // right free list.
                }
            }
      _S_end_free = 0;  // In case of exception.
            _S_start_free = (char*)malloc_alloc::allocate(__bytes_to_get);
            // This should either throw an
            // exception or remedy the situation.  Thus we assume it
            // succeeded.
        }
        _S_heap_size += __bytes_to_get;
        _S_end_free = _S_start_free + __bytes_to_get;
        return(_S_chunk_alloc(__size, __nobjs));
    }
}
```

####第二级适配器内存释放

1. 如果空间大于_MAX_BYTES（128 bytes），调用第一级适配器dealloc释放。
 
2. 否则从free_list数组中找到相应的free内存链，将要释放的内存链回到free_list。

从上述过程来看，内存释放实际上并没有把内存还给操作系统而是重新链回到内存池中。

```
  /* __p may not be 0 */
  static void deallocate(void* __p, size_t __n)
  {
    if (__n > (size_t) _MAX_BYTES)
      malloc_alloc::deallocate(__p, __n);
    else {
      _Obj* __STL_VOLATILE*  __my_free_list
          = _S_free_list + _S_freelist_index(__n);
      _Obj* __q = (_Obj*)__p;

      // acquire lock
#       ifndef _NOTHREADS
      /*REFERENCED*/
      _Lock __lock_instance;
#       endif /* _NOTHREADS */
      __q -> _M_free_list_link = *__my_free_list;
      *__my_free_list = __q;
      // lock is released here
    }
  }
```


## 参考资料
1. [深入探究C++的new/delete操作符][c++ new delete]

[c++ new delete]: http://kelvinh.github.io/blog/2014/04/19/research-on-operator-new-and-delete/