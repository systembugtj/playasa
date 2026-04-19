#include "stdafx.h"
#include "MediaSpiderFolderTree.h"
#include "..\Controller\PlayerPreference.h"
#include "..\Controller\SPlayerDefs.h"
#include "..\Utils\FilesystemCompat.h"

////////////////////////////////////////////////////////////////////////////////
// Normal part
MediaSpiderFolderTree::MediaSpiderFolderTree()
{
  // Init the last search path from the database
  m_sLastSearchPath = PlayerPreference::GetInstance()->GetStringVar(STRVAR_LASTSPIDERPATH);

  // Init the media type and the exclude folders & files from the database
  // Warning: the case is sensitive !!!
  SetSupportExtension(L".avi");
  SetSupportExtension(L".wmv");
  SetSupportExtension(L".mkv");
  SetSupportExtension(L".rmvb");
  SetSupportExtension(L".rm");
  SetSupportExtension(L".asf");
  SetSupportExtension(L".mov");
  SetSupportExtension(L".mp4");
  SetSupportExtension(L".mpeg");
  SetSupportExtension(L".3gp");
  SetSupportExtension(L".divx");

  SetExcludePath(L"c:\\Windows\\");
  SetExcludePath(L"C:\\Program Files\\");
  SetExcludePath(L"C:\\Program Files (x86)\\");
}

MediaSpiderFolderTree::~MediaSpiderFolderTree()
{
  // Store the last search path, if the path is NULL, then represent the last
  // search is a complete search
  PlayerPreference::GetInstance()->SetStringVar(STRVAR_LASTSPIDERPATH, m_sLastSearchPath);
}

bool _sort_tree_folders(const MediaTreeFolder &treeFolder1, const MediaTreeFolder &treeFolder2)
{
  return treeFolder1.nMerit > treeFolder2.nMerit;  // descending order
}

//void cDebug(const std::wstring &sDebugInfo, bool bAutoBreak = true)
//{
//  if (::GetStdHandle(STD_OUTPUT_HANDLE) == 0)
//    ::AllocConsole();
//
//  HANDLE h = ::GetStdHandle(STD_OUTPUT_HANDLE);
//
//  if (bAutoBreak)
//  {
//    ::WriteConsole(h, sDebugInfo.c_str(), sDebugInfo.size(), 0, 0);
//    ::WriteConsole(h, L"\n", 1, 0, 0);
//  } 
//  else
//  {
//    ::WriteConsole(h, sDebugInfo.c_str(), sDebugInfo.size(), 0, 0);
//  }
//}

void MediaSpiderFolderTree::_Thread()
{
  using std::wstring;
  using std::vector;
  using std::list;

  while (true)
  {
    // see if need to be stop
    if (_Exit_state(0))
      return;

    // sort the path according the merit by descending order
    MediaTreeFolders treeFolders = m_treeModel.mediaTreeFolders();
    treeFolders.sort([](const MediaTreeFolder &a, const MediaTreeFolder &b) {
      return a.nMerit > b.nMerit;
    });

    //// for test
    //MediaTreeFolders::const_iterator itTest = treeFolders.begin();
    //while (itTest != treeFolders.end())
    //{
    //  std::wstringstream ss;
    //  ss << L"folder = " << itTest->sFolderPath << L", tFolderCreateTime = " << itTest->tFolderCreateTime;
    //  cDebug(ss.str());

    //  ++itTest;
    //}
    //cDebug(L"");

    // search the media files
    MediaTreeFolders::const_iterator it = treeFolders.begin();
    while (it != treeFolders.end())
    {
      // see if need to be stop
      if (_Exit_state(0))
        return;

      // search the path for media files
      if (it->tNextSpiderInterval == 0)
        Search(it->sFolderPath);
      else if (((::time(0) - it->tFolderCreateTime) % it->tNextSpiderInterval) == 0)
        Search(it->sFolderPath);

      ++it;
    }

    // sleep for a moment
    ::Sleep(300);
  }
}

void MediaSpiderFolderTree::Search(const std::wstring &sFolder)
{
  using std::wstring;
  using std::vector;
  // see if need to be stop
  if (_Exit_state(0))
    return;  

  // if the folder is not exist or the folder is been exclude, then return
  if (!mpc_fs::is_directory(mpc_fs::path(sFolder)) || IsExcludePath(sFolder))
    return;

  // search the folder
  const mpc_fs::path folder(sFolder);
  for (const mpc_fs::directory_entry &ent : mpc_fs::directory_iterator(folder))
  {
    const mpc_fs::path entryPath = ent.path();
    if (mpc_fs::is_regular_file(entryPath) && IsSupportExtension(entryPath.wstring()))
    {
      // add it to the folder tree
      MediaData md;
      md.path = sFolder;
      md.filename = entryPath.filename().wstring();
      
      m_treeModel.addFile(md);
    }

    // sleep for a moment
    ::Sleep(50);
  }
}