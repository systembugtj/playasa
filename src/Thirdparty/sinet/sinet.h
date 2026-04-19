/**
 * @file sinet.h
 * @brief 无厂商 sinet.dll 时的占位实现：同步完成“请求”，固定失败码，避免链接外部库。
 */
#pragma once

#include <map>
#include <memory>
#include <string>
#include <vector>

namespace sinet {

typedef std::vector<unsigned char> si_buffer;
typedef std::map<std::wstring, std::wstring> si_stringmap;

template <class T>
class refptr {
  std::shared_ptr<T> sp_;

public:
  refptr() : sp_() {}
  explicit refptr(std::shared_ptr<T> p) : sp_(std::move(p)) {}
  refptr(const refptr&) = default;
  refptr& operator=(const refptr&) = default;

  T* operator->() const { return sp_.get(); }
  T& operator*() const { return *sp_; }
  explicit operator bool() const { return static_cast<bool>(sp_); }
};

class postdataelem {
public:
  static refptr<postdataelem> create_instance() {
    return refptr<postdataelem>(std::shared_ptr<postdataelem>(new postdataelem()));
  }
  void set_name(const wchar_t* /*name*/) {}
  void setto_text(const wchar_t* /*text*/) {}
  void setto_file(const wchar_t* /*path*/) {}
};

class postdata {
public:
  static refptr<postdata> create_instance() {
    return refptr<postdata>(std::shared_ptr<postdata>(new postdata()));
  }
  void add_elem(refptr<postdataelem> /*elem*/) {}
};

class config {
public:
  static refptr<config> create_instance() {
    return refptr<config>(std::shared_ptr<config>(new config()));
  }
  void set_strvar(int /*id*/, const wchar_t* /*value*/) {}
  void set_strvar(int id, const std::wstring& value) { set_strvar(id, value.c_str()); }
};

class request {
  int response_errcode_;
  si_buffer response_buffer_;
  si_stringmap response_headers_;
  si_stringmap request_headers_;
  int outmode_;

  friend class task;

public:
  request() : response_errcode_(0), outmode_(0) {}

  static refptr<request> create_instance() {
    return refptr<request>(std::shared_ptr<request>(new request()));
  }

  void set_request_url(const wchar_t* /*url*/) {}
  void set_request_method(int /*method*/) {}
  void set_postdata(refptr<postdata> /*data*/) {}
  void set_request_header(si_stringmap& h) { request_headers_ = h; }
  void set_request_outmode(int m) { outmode_ = m; }
  void set_outfile(const wchar_t* /*path*/) {}

  int get_response_errcode() const { return response_errcode_; }
  si_buffer get_response_buffer() const { return response_buffer_; }
  si_stringmap& get_response_header() { return response_headers_; }

private:
  void apply_stub_result() {
    (void)outmode_;
    (void)request_headers_;
    response_errcode_ = 1;
    response_buffer_.clear();
    response_headers_.clear();
  }
};

class task {
  std::vector<refptr<request>> pending_;
  refptr<config> cfg_;

public:
  static refptr<task> create_instance() {
    return refptr<task>(std::shared_ptr<task>(new task()));
  }
  void use_config(refptr<config> c) { cfg_ = c; }
  void append_request(refptr<request> r) {
    if (r) {
      pending_.push_back(r);
    }
  }
  void run_pending_stub() {
    for (size_t i = 0; i < pending_.size(); ++i) {
      if (pending_[i]) {
        pending_[i]->apply_stub_result();
      }
    }
    pending_.clear();
    (void)cfg_;
  }
};

class pool {
public:
  static refptr<pool> create_instance() {
    return refptr<pool>(std::shared_ptr<pool>(new pool()));
  }
  void execute(refptr<task> t) {
    if (t) {
      t->run_pending_stub();
    }
  }
  bool is_running_or_queued(refptr<task> /*t*/) const { return false; }
};

} // namespace sinet

// 与旧版 sinet 头一致：宏在全局命名空间，供未写 sinet:: 前缀的 .cc 使用
#ifndef REQ_GET
#define REQ_GET 0
#endif
#ifndef REQ_POST
#define REQ_POST 1
#endif
#ifndef REQ_OUTFILE
#define REQ_OUTFILE 2
#endif
#ifndef CFG_STR_AGENT
#define CFG_STR_AGENT 1
#endif
#ifndef CFG_STR_PROXY
#define CFG_STR_PROXY 2
#endif
