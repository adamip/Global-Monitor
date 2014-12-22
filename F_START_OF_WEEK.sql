/* 
	http://www.sqlteam.com/forums/topic.asp?TOPIC_ID=47307
*/


create function F_START_OF_WEEK
(
	@DATE			datetime,
	-- Sun = 1, Mon = 2, Tue = 3, Wed = 4
	-- Thu = 5, Fri = 6, Sat = 7
	-- Default to Sunday
	@WEEK_START_DAY		int	= 1	
)
/*
Find the fisrt date on or before @DATE that matches 
day of week of @WEEK_START_DAY.
*/
returns		datetime
as
begin
declare	 @START_OF_WEEK_DATE	datetime
declare	 @FIRST_BOW		datetime

-- Check for valid day of week
if @WEEK_START_DAY between 1 and 7
	begin
	-- Find first day on or after 1753/1/1 (-53690)
	-- matching day of week of @WEEK_START_DAY
	-- 1753/1/1 is earliest possible SQL Server date.
	select @FIRST_BOW = convert(datetime,-53690+((@WEEK_START_DAY+5)%7))
	-- Verify beginning of week not before 1753/1/1
	if @DATE >= @FIRST_BOW
		begin
		select @START_OF_WEEK_DATE = 
		dateadd(dd,(datediff(dd,@FIRST_BOW,@DATE)/7)*7,@FIRST_BOW)
		end
	end

return @START_OF_WEEK_DATE

end