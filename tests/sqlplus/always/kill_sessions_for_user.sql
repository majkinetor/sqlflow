begin
 for sessions in ( select sid, serial# 
                    from   v$session 
                    where  username = '&1') 
  loop
    execute immediate 'alter system kill session '''||sessions.sid||','||sessions.serial#||'''';
  end loop;
end;
/
