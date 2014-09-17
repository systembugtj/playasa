#ifndef USERBEHAVIORDATA_H
#define USERBEHAVIORDATA_H

#include "..\..\..\..\Thirdparty\sqlitepp\sqlitepp\session.hpp"
#include "..\..\..\..\Thirdparty\sqlitepp\sqlitepp\sqlitepp.hpp"
#include "..\..\..\..\Thirdparty\sqlitepp\sqlitepp\transaction.hpp"


#define USRBHV_STARTSPLAYER  1
#define USRBHV_CLOSESPLAYER  2

// _%s_%s_%d format
// uuid_year_weekcount
#define DATABASE_NAME        L"splayer_ubdb_%s_%d_%d.log"
#define LOGFILE_FORMAT       L"splayer_ubdb_%s_%d_*.log"

class UsrBehaviorData
{
public:
	~UsrBehaviorData();
	void AppendBhvEntry(int id, std::wstring data);
	void AppendEnvEntry(std::wstring name, std::wstring data);
	static void GetYearAndWeekcount(int& year, int& weekcount);

private:
	// create and fill a new environment data table
	void SetEnvironmentData();

	struct UsrBehaviorEntry
	{
		int          id;
		sqlitepp::string_t data;
		double       time;
	};

	struct UsrEnvEntry
	{
		sqlitepp::string_t name;
		sqlitepp::string_t data;
	};

	std::vector<UsrBehaviorEntry> ubhv_entries;
	std::vector<UsrEnvEntry>  env_entries;
};
#endif // USERBEHAVIORDATA_H