#ifndef BASE_LAZYINSTANCE_H
#define BASE_LAZYINSTANCE_H

#include <memory>

template<class T>
class LazyInstanceImpl
{
public:
  static std::unique_ptr<T> m_instance;
  static T* GetInstance()
  {
    if (m_instance.get())
      return m_instance.get();
    else
    {
      m_instance.reset(new T());
      return m_instance.get();
    }
  }
};

#define DECLARE_LAZYINSTANCE(classname) \
  std::unique_ptr<classname> LazyInstanceImpl<classname>::m_instance;

#endif // BASE_LAZYINSTANCE_H
