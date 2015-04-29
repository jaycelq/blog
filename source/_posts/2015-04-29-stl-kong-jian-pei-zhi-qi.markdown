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


## 参考资料
1. [深入探究C++的new/delete操作符][c++ new delete]

[c++ new delete]: http://kelvinh.github.io/blog/2014/04/19/research-on-operator-new-and-delete/