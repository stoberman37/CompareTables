--************************************************************************************************************************************************
--*	Procedure:	CompareTables
--*	Description:	This procedure compares two tables of views, returning any rows from either table which do not match, along with the 
--*					name of the table it is from.
--*
--*	Parameters:
--*			* @table1				- name of the first table or view to compare
--*			* @table2				- name of the second table or veiw to compare
--*			* @T1ColumnList			- comma separated list of the columns from @table1 to compare
--*			* @T2ColumnList			- optional comma separated list of the columns from @table2 to compare, in the same order as the columns
--*									  in @T1ColumnList.  If not provided, @T1ColumnList is assumed.
--*			* @T1WhereClause		- optional where clause applied to @table1
--*			* @T2WhereClause		- optional where clause applied to @table2
--*			* @MasterColumnList		- optional comma separated list of columns to select from teh results of the UNION of @table1 and @table2. 
--*									  If not provided, @T1ColumnList is assumed.
--* 		* @OrderByColumnList	- optional comma separated list of columns to order the output.  If not provided, @T1ColumnList is assumed.
--*			* @debug				- optional flag which causes the procedure to output as a PRINT statement the query that is constructed
--*								  
DROP PROCEDURE IF EXISTS [dbo].[CompareTables] 
GO 

CREATE PROCEDURE [dbo].[CompareTables](
	  @table1 VARCHAR(MAX)
	, @table2 VARCHAR(MAX)
	, @T1ColumnList VARCHAR(MAX)
	, @T2ColumnList VARCHAR(MAX) = ''
	, @T1WhereClause VARCHAR(MAX) = ''
	, @T2WhereClause VARCHAR(MAX) = ''
	, @MasterColumnList VARCHAR(MAX) = ''
	, @OrderByColumnList VARCHAR(MAX) = ''
	, @debug BIT = 0
)
AS
BEGIN
	DECLARE @SQL NVARCHAR(MAX);
	IF ISNULL(@t2ColumnList,'') = '' SET @T2ColumnList = @T1ColumnList
	IF ISNULL(@MasterColumnList,'') = '' SET @MasterColumnList = @T1ColumnList
	IF ISNULL(@OrderByColumnList,'') = '' SET @OrderByColumnList = @MasterColumnList

	set @SQL = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
					  CAST('SELECT 
								MAX(TableName) as TableName, 
								{MasterColumnList} FROM (
									SELECT ''{Table1}'' AS TableName
											, {T1ColumnList} 
										FROM {Table1} 
										{T1WhereClause} 
									UNION ALL 
									SELECT ''{Table2}'' As TableName
											, {T2ColumnList} 
										FROM {Table2} 
										{T2WhereClause}
									) A GROUP BY {MasterColumnList} 
									HAVING COUNT(1) <> 2
									ORDER BY {OrderByColumnList}' AS VARCHAR(MAX))
					, '{Table1}', @Table1)
					, '{Table2}', @Table2)
					, '{MasterColumnList}', @MasterColumnList)
					, '{OrderByColumnList}', @OrderByColumnList)
					, '{T1ColumnList}', @T1ColumnList)
					, '{T2ColumnList}', @T2ColumnList)
					, '{T1WhereClause}', COALESCE(@T1WhereClause, ''))
					, '{T2WhereClause}', COALESCE(@T2WhereClause, ''))

	-- PRINT here won't output the entire query when it's over 8000 characters
	IF @debug = 1
	BEGIN
		SELECT [Script] = CAST('<A><![CDATA[
		' + @sql + ']]></A>' AS xml)
	END 

	-- Execute the query
	exec sp_executesql @SQL
END
GO
