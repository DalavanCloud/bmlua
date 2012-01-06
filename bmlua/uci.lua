module(..., package.seeall);

function parse_bool(s)
    -- interpret the many ways true or false can be expressed in UCI.
    local retval = nil
    s = s:lower()
    if s == 'true' or s == '1' or s == 'yes' then
        retval = true
    elseif s == 'false' or s == '0' or s == 'no' then
        retval = false
    end 
    return retval
end
