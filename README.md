# CompareTables
Simple script to to a simple job - compare two tables.  Actually, this will basically work on anything which can be viewed a set of results - a table, a view, probably even a table-valued function.  (Caveat - its never been tested with a table-valued function, but as long as the script that's generated would call it correctly, this should work.)

It's a deceptively simple script - basically, you just select from both tables, UNION ALL them together, and then GROUP BY.  When a row from each table is equal to one another, you will end up with a COUNT of 2.  So any of the GROUP BYs not having a count of 2 means a mismatch.  

## Parameters
The stored procedure accepts the following parameters
Name|Description|Type|Default
---|---|---|---
@table1|REQUIRED - name of the first table or view to compare|NVARCHAR(MAX)|*&lt;none&gt;*
@table2|REQUIRED - name of the second table or veiw to compare|NVARCHAR(MAX)|*&lt;none&gt;*
@T1ColumnList|REQUIRED - comma separated list of the columns from @table1 to compare|NVARCHAR(MAX)|*&lt;none&gt;*
@T2ColumnList|optional comma separated list of the columns from @table2 to compare, in the same order as the columns in @T1ColumnList.  If not provided, @T1ColumnList is assumed.|NVARCHAR(MAX)|''
@T1WhereClause|optional where clause applied to @table1|NVARCHAR(MAX)|''
@T2WhereClause|optional where clause applied to @table2|NVARCHAR(MAX)|''
@MasterColumnList|optional comma separated list of columns to select from teh results of the UNION of @table1 and @table2. If not provided, @T1ColumnList is assumed.|NVARCHAR(MAX)|''
@OrderByColumnList|optional comma separated list of columns to order the output. If not provided, @T1ColumnList is assumed.|NVARCHAR(MAX)|''
@debug|optional flag which causes the procedure to output as a PRINT statement the query that is constructed|BIT|0

## Example usage
Consider the following very contrived example.  This was done using sqllocaldb in the master database.

In this test, if I run 

	SELECT name, object_id, principal_id, schema_id FROM sys.tables

I get the following results:

| name                  | object_id  | principal_id | schema_id |
|-----------------------|------------|--------------|-----------|
| spt_fallback_db       | 117575457  | NULL         | 1         |
| spt_fallback_dev      | 133575514  | NULL         | 1         |
| spt_fallback_usg      | 149575571  | NULL         | 1         |
| spt_monitor           | 1483152329 | NULL         | 1         |
| MSreplication_options | 1787153412 | NULL         | 1         |

In the scenario, I want to compare sys.tables against itself, but I want to exclude tables starting with 'MS' from the first set of results, and tables spt_fallback_dev and spt_fallback_db from the set of results.  In addition, I only care about the name, object_id, and schema_id columns.  Finally, just to trow a wrench into it, I want to add 1 to the schema_id in the second set of results.  (I warned you this was contrived.)

Given that scenario, here's the script I need to run.

	DECLARE 
		@table1 VARCHAR(MAX)
		, @table2 VARCHAR(MAX)
		, @T1ColumnList VARCHAR(MAX)
		, @T2ColumnList VARCHAR(MAX)
		, @T1WhereClause VARCHAR(MAX)
		, @T2WhereClause VARCHAR(MAX)

	SET @table1 = 'sys.tables t1'
	SET @table2 = 'sys.tables t2'
	SET @T1ColumnList = 'name, object_id, schema_id'
	SET @T2ColumnList = 'name, object_id, schema_id=schema_id+1'
	SET @T1WhereClause = 'WHERE name not like ''MS%'''
	SET @T2WhereClause = 'WHERE name NOT IN (''spt_fallback_dev'', ''spt_fallback_db'')'

	EXEC [dbo].[CompareTables]
		@table1 = @table1 
		, @table2 = @table2
		, @T1ColumnList = @T1ColumnList
		, @T2ColumnList = @T2ColumnList
		, @T1WhereClause = @T1WhereClause
		, @T2WhereClause = @T2WhereClause 

which yields the following results:

| TableName     | name                  | object_id  | schema_id |
|---------------|-----------------------|------------|-----------|
| sys.tables t2 | MSreplication_options | 1787153412 | 2         |
| sys.tables t1 | spt_fallback_db       | 117575457  | 1         |
| sys.tables t1 | spt_fallback_dev      | 133575514  | 1         |
| sys.tables t1 | spt_fallback_usg      | 149575571  | 1         |
| sys.tables t2 | spt_fallback_usg      | 149575571  | 2         |
| sys.tables t1 | spt_monitor           | 1483152329 | 1         |
| sys.tables t2 | spt_monitor           | 1483152329 | 2         |

If, however, I exclude the schema_id from the columns being compared (by changing the MasterColumnList value as follows)

	DECLARE 
		@table1 VARCHAR(MAX)
		, @table2 VARCHAR(MAX)
		, @T1ColumnList VARCHAR(MAX)
		, @T2ColumnList VARCHAR(MAX)
		, @T1WhereClause VARCHAR(MAX)
		, @T2WhereClause VARCHAR(MAX)
		, @MasterColumnList VARCHAR(MAX)

	SET @table1 = 'sys.tables t1'
	SET @table2 = 'sys.tables t2'
	SET @T1ColumnList = 'name, object_id, schema_id'
	SET @T2ColumnList = 'name, object_id, schema_id=schema_id+1'
	SET @T1WhereClause = 'WHERE name not like ''MS%'''
	SET @T2WhereClause = 'WHERE name NOT IN (''spt_fallback_dev'', ''spt_fallback_db'')'
	set @MasterColumnList = 'name, object_id'

	EXEC [dbo].[CompareTables]
		@table1 = @table1 
		, @table2 = @table2
		, @T1ColumnList = @T1ColumnList
		, @T2ColumnList = @T2ColumnList
		, @T1WhereClause = @T1WhereClause
		, @T2WhereClause = @T2WhereClause 
		, @MasterColumnList = @MasterColumnList 

the output is very different, and only shows the excluded tables.

| TableName     | name                  | object_id  |
|---------------|-----------------------|------------|
| sys.tables t2 | MSreplication_options | 1787153412 |
| sys.tables t1 | spt_fallback_db       | 117575457  |
| sys.tables t1 | spt_fallback_dev      | 133575514  |

Why is that important?  This demonstrates a couple of things. First, your comparison doesnt have to include all of the columns in table 1 and table 2.  In fact, because table1 and table2 have separate column lists, those columns dont even have to be the same name, or even the same type (as long as the can be converted to the same type, which you can do by manipulating them in the table1 and table2 column lists.  Second, even when you have differences in the column lists, you an use the MasterColumnList to further control columns are compared, and in what order. 

## Hints and Tips
I used this script for a long time without the OrderByColumnList.  And once I added it, I wished I'd added it sooner.  That's invaluable when you have a set of columns that will pretty much always match (primary and natural key columns, for instance).  I've found it most useful to put those columns first, followed by the TableName column which is added by the script. In large sets, this allows the output to come out in a way where the two records which are mismatched are one after the other. 

## Caveats
I believe this should work with only minor modifications on most relational sql instances. However, it's only been used thus var on variants of MS SQL Server, so YMMV. 