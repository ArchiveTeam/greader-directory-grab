--[[
Based on https://github.com/ArchiveTeam/greader-grab/blob/master/greader.lua
--]]

read_file = function(file, amount)
  local f = io.open(file)
  local data = f:read(amount)
  f:close()
  return data
end

-- Yes, really, lua does not come with an API to popen without a shell, or escape
-- a shell argument.
ensure_safe_and_quote_shell_arg = function(arg)
  -- http://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html
  assert(string.find(arg, "[\\`$\"\'\n\r\t\b\f\v]") == nil, "Argument contains unsafe characters: " .. arg)
  -- Must use single quote
  return "'" .. arg .. "'"
end

read_gz_file = function(file, amount)
  -- Need to redirect stderr to /dev/null to avoid getting "Broken pipe"
  -- spew when we don't read the whole thing
  local p = io.popen("gunzip -c -- " .. ensure_safe_and_quote_shell_arg(file) .. " 2> /dev/null")
  local data = p:read(amount)
  p:close()
  return data
end

url_count = 0

url_with_start = function(url, start)
  if string.find(url, "&start=[0-9]+") then
    return string.gsub(url, "&start=[0-9]+", "&start=" .. start, 1)
  end
  return url .. "&start=" .. start
end

current_start = 0

wget.callbacks.get_urls = function(file, url, is_css, iri)
  if not string.find(url, "&start=[0-9]+") then
    current_start = 0
  end

  -- progress message
  url_count = url_count + 1
  if url_count % 500 == 0 then
    print(" - Downloaded "..url_count.." URLs")
  end

  if not file then
    return {}
  end

  local magic = read_file(file, 2) -- returns nil if file is empty
  if not magic then
    return {}
  end

  -- Support both gzip and uncompressed responses
  -- Read 32KB in case the feed has a really long title
  -- Magic bytes from http://www.gzip.org/zlib/rfc-gzip.html
  -- Note that Lua escapes are decimal, not octal
  local page
  if magic == "\031\139" then
    page = read_gz_file(file, 32768) -- returns nil if file is empty
  else
    page = read_file(file, 32768) -- returns nil if file is empty
  end

  if not page then
    return {}
  end

  if string.match(page, ',"hasnextpage":true,') then
    current_start = current_start + 10
    return {{url=url_with_start(url, current_start), link_expect_html=0}}
  end

  return {}
end

wget.callbacks.httploop_result = function(url, err, http_stat)
  code = http_stat.statcode
  if not code == 200 then
    -- Long delay because people like to run with way too much concurrency
    delay = 600

    io.stdout:write("\nServer returned status "..code.."; we may need a new Google cookie.\n")
    io.stdout:write("Please report this to #donereading.  Waiting for "..delay.." seconds and exiting...\n")
    io.stdout:flush()

    os.execute("sleep "..delay)
    -- We have to give up on this WARC; we don't want to upload anything with
    -- error responses to the upload target
    return wget.actions.ABORT

  else
    return wget.actions.NOTHING
  end
end
