require "net/http"
require "cgi"
require "uri"

class Plurk
  attr_reader :logged_in, :uid, :nickname, :friends, :cookie, :plurk_qualifiers
  def initialize
    @plurk_paths = {
      :http_base            => "www.plurk.com",
      :login                => "/Users/login",
      :get_completion       => "/Users/getCompletion",
      :plurk_add            => "/TimeLine/addPlurk",
      :plurk_respond        => "/Responses/add",
      :plurk_get            => "/TimeLine/getPlurks",
      :plurk_get_responses  => "/Responses/get2",
      :plurk_get_unread     => "/TimeLine/getUnreadPlurks",
      :plurk_mute           => "/TimeLine/setMutePlurk",
      :plurk_delete         => "/TimeLine/deletePlurk",
      :notification         => "/Notifications",
      :notification_accept  => "/Notifications/allow",
      :notification_makefan => "/Notifications/allowDontFollow",
      :notification_deny    => "/Notifications/deny",
      :friends_get          => "/Users/friends_get",
      :friends_block        => "/Friends/blockUser",
      :friends_remove_block => "/Friends/removeBlock",
      :friends_get_blocked  => "/Friends/getBlockedByOffset",
      :user_get_info        => "/Users/fetchUserInfo",
    }

    @plurk_qualifiers = {
      :loves   => "loves",
      :likes   => "likes",
      :shares  => "shares",
      :gives   => "gives",
      :hates   => "hates",
      :wants   => "wants",
      :wishes  => "wishes",
      :needs   => "needs",
      :will    => "will",
      :hopes   => "hopes",
      :asks    => "asks",
      :has     => "has",
      :was     => "was",
      :wonders => "wonders",
      :feels   => "feels",
      :thinks  => "thinks",
      :says    => "says",
      :is      => "is",
    }

    @plurk_languages = {
      :en      => "en",
      :ar      => "ar",
      :ca      => "ca",
      :cs      => "cs",
      :da      => "da",
      :de      => "de",
      :el      => "el",
      :es      => "es",
      :fil     => "fil",
      :fr      => "fr",
      :hu      => "hu",
      :id      => "id",
      :it      => "it",
      :nb      => "nb",
      :nl      => "nl",
      :pl      => "pl",
      :pt_BR   => "pt_BR",
      :ro      => "ro",
      :ru      => "ru",
      :zh_CN   => "zh_CN",
      :zh_Hant => "zh_Hant",
    }
  end

  def login(nickname, password)
    http = Net::HTTP.start(@plurk_paths[:http_base])
    resp, data = http.request_post(@plurk_paths[:login],
                 hash_to_querystring({"redirect_page" => "main", "nick_name" => nickname, "password" => password}))
    @cookie = resp.response["set-cookie"]
    html = http.get(data)
    /var GLOBAL = \{.*"uid": ([\d]+),.*\}/imu =~ html.body
    @uid = Regexp.last_match[1]
    resp, data = http.request_post(@plurk_paths[:get_completion],
                 hash_to_querystring({"user_id" => @uid}))
    @friends = json_to_ruby(data)
    @nickname = nickname
    http.finish
    @logged_in = true
  end

  #it would be nice if we can return the plurk_id of this new plurk - ddmanlin
  def add_plurk(content="", qualifier=@plurk_qualifier[:says], limited_to=[], no_comments=false, lang=@plurk_languages[:en])
    if @logged_in
      http = Net::HTTP.start(@plurk_paths[:http_base])
      no_comments = no_comments ? 1 : 0
      params = {
                 "posted" => Time.now.getgm.strftime("%Y-%m-%dT%H:%M:%S"),
                 "qualifier" => qualifier,
                 "content" => content[0...140],
                 "lang" => lang,
                 "uid" => @uid,
                 "no_comments" => no_comments
               }
      params["limited_to"] = "[#{limited_to.join(",")}]" unless limited_to.empty?
      resp, data = http.request_post(@plurk_paths[:plurk_add],
                   hash_to_querystring(params),{"Cookie" => @cookie})
      return data if /anti-flood|/.match(data)
      content
    end
  end

  def get_alerts
    # if not login return false
    # get [:notification]
    # re.compile('DI\s*\(\s*Notifications\.render\(\s*(\d+),\s*0\)\s*\);')
    # re.match, return match
  end

  def befriend(uids, friend)
    # if not login return false
    # path = friend ? [:notification_accept] : [:notification_deny]
    # for each uids
    # post path ? friend_id=uid
    # puts "something"
    # return true
  end

  def deny_friend_make_fan(uids)
    # if not login return false
    # if uids not array return false
    # for each uids
    # post [:notofication_makefan] ? friend_id=uid
    # puts "added fan"
    # return true
  end

  def block_user(uids)
    # if not login return false
    # for each uids
    # post [:friends_block] ? block_uid=uid
    # puts "blocked" uid
    # return true
  end

  def unblock_user(uids)
    # if not login return false
    # for each uids
    # post [:friends_remove_block] ? friend_id = uid
    # puts "unblocked"+ uid
    # return true
  end

  def get_blocked_users
    # if not login return false
    # post [:friends_get_blocked] ? offset=0 & user_id=@uid
    # return body | json_to_hash
  end

  def mute_plurk(plurk_id, setmute)
    # if not login return false
    # convert setmute to integer
    # post [:plurk_mute] ? plurk_id=plurk_id & value=setmute
    # if body == setmute return true else false
  end

  def delete_plurk(plurk_id)
    if @logged_in

      #first make sure the plurk exists
      resp = Net::HTTP.get_response(URI.parse(get_permalink(plurk_id)))
      return false if resp.code == "404" #make sure it exists

      #delete the existing plurk
      http = Net::HTTP.start(@plurk_paths[:http_base])
      params = {
                 "plurk_id" => plurk_id
               }
      resp, data = http.request_post(@plurk_paths[:plurk_delete],
                   hash_to_querystring(params),{"Cookie" => @cookie})

      return resp.body ? true : false
    end
    # if not login return false
    # post [:plurk_delete] ? plurk_id=plurk_id
    # if response.body ok, return true else false
  end

  def get_plurks(uid=nil, date_from=nil, date_offset=nil, fetch_responses=false)
    uid ||= @uid
    # TODO date_offset? fetch_responses?
    # post [:plurk_get] ? user_id=uid & from_date=date_from(if not nil)
    # return json_to_hash response
  end

  def get_unread_plurks(fetch_responses=false)
    # if not login return []
    # get [:plurk_get_unread], json_to_hash
    # for each hash item,
    # item["nick_name"] = uid_to_nickname ["owner_id"]
    # item["responses_fetched"] = null
    # plurk["permalink"] = get_permalink(item["plurk_id"])
    # if fetch_responses == true
    # item["responses_fetched"] = plurk_get_responses(item["plurk_id"])
    # return hash
  end

  def uid_to_nickname(uid)
    if @logged_in
      nickname ||= -1
      if uid == @uid
        nickname = @nickname
      else
        for friend in @friends
          nickname = friend[1]["nick_name"] if uid.to_s == friend[0]
        end
      end
      return nickname
    end
    # if uid = @uid return @nickname
    # if uid = friends.@uid, return friends.@nickname
    # return Unknown User uid
  end

  #not working by  ddmanlin
  def respond_to_plurk(plurk_id, content="", qualifier=@plurk_qualifier[:says], lang=@plurk_languages[:en])
#    if @logged_in
#      http = Net::HTTP.start(@plurk_paths[:http_base])
#      params = {
#                 "plurk_id" => plurk_id,
#                 "uid" => @uid,
#                 "pid" => @uid,
#                 "lang" => lang,
#                 "content" => content[0...140],
#                 "qualifier" => qualifier,
#                 "posted" => Time.now.getgm.strftime("%Y-%m-%dT%H:%M:%S"),
#               }
#      resp, data = http.request_post(@plurk_paths[:plurk_respond],
#                   hash_to_querystring(params),{"Cookie" => @cookie})
#      p resp
#      p data
#      content
#    end
    # if not log in return false
    # post [:plurk_respond] ? plurk_id=plurk_id & uid=@uid & p_uid=@uid & lang=lang & content=content[0:140]
    # qualifier=qualifier & posted = Time.now
  end

  def get_responses(plurk_id)
    if @logged_in
      http = Net::HTTP.start(@plurk_paths[:http_base])
      params = { "plurk_id" => plurk_id }
      resp, data = http.request_post(@plurk_paths[:plurk_get_responses],
                 hash_to_querystring(params),{"Cookie" => @cookie})
      return data
    end
    # post [:plurk_get_responses] ? plurk_id=plurk_id
  end

  def nickname_to_uid(nickname)
    http = Net::HTTP.start(@plurk_paths[:http_base])
    resp = http.request_get("/user/#{nickname}")
    /var GLOBAL = \{.*"uid": ([0-9]+),.*\}/imu =~resp.body
    uid = Regexp.last_match[1]
    unless uid
      return -1
    else
      return uid
    end
    # get [:http_base]/user/nickname
    # if didn't match regexp match var GLOBAL "uid": xxx return -1
    # return match[1]
  end

  def uid_to_userinfo(uid)
    if @logged_in
      http = Net::HTTP.start(@plurk_paths[:http_base])
      params = { "user_id" => uid }
      resp = http.request_get(@plurk_paths[:user_get_info]+"?"+hash_to_querystring(params),{"Cookie" => @cookie})
      if resp.code == "500"
        return {}
      else
        return resp.body
      end
    end
    # array_profile = get [:user_get_info] ? user_id=uid
    # if respond code = 500 return []
    # return array_profile["body"]
  end

  def get_permalink(plurk_id)
    return "http://www.plurk.com/p/#{plurk_id.to_s(36)}"
    # return "http://www.plurk.com/p/" + plurk_id to base36
  end

  def permalink_to_plurk_id(permalink)
    /http:\/\/www.plurk.com\/p\/([a-zA-Z0-9]*)/ =~ permalink
    return $1.to_i(36)
    # base36 = gsub "http://www.plurk.com/p/" ""
    # convert base36 to decimal
  end

  private
    def json_to_ruby(json)
      /new Date\((.*)\)/.match(json)
      json = json.gsub(/new Date\(.*\)/, Regexp.last_match[1]) if Regexp.last_match
      null = nil
      return eval(json.gsub(/(["'])\s*:\s*(['"\-?0-9tfn\[{])/){"#{$1}=>#{$2}"})
    end

    def hash_to_querystring(hash)
      qstr = ""
      hash.each do |key,val|
        qstr += "#{key}=#{CGI.escape(val.to_s)}&" unless val.nil?
      end
      qstr
    end

end

if __FILE__ == $0
  if ARGV.length != 2
    $stderr.puts "Usage: ruby #{$0} [nickname] [password]"
  else
    plurker = Plurk.new
    puts "Login: " + plurker.login(ARGV.shift, ARGV.shift).inspect
#    puts "Sent: " + plurker.add_plurk("testing Plurk API http://tinyurl.com/6r4nfv", plurker.plurk_qualifiers[:is]).inspect
#    puts "uid to nickname: " + plurker.uid_to_nickname(plurker.uid).inspect #user
#    puts "uid to nickname: " + plurker.uid_to_nickname(plurker.friends.keys[0]).inspect #1st friend
#    puts "delete plurk: " + plurker.delete_plurk(plurker.permalink_to_plurk_id("http://www.plurk.com/p/2o8jc")).inspect
#    puts "response: " + plurker.respond_to_plurk(4183588, "test response", "is").inspect
#    puts "get response: " + plurker.get_responses(4183588).inspect #response of http://www.plurk.com/p/2ho2s
#    puts "nickname to uid: " + plurker.nickname_to_uid(plurker.nickname).inspect
#    puts "uid to info: " + plurker.uid_to_userinfo(plurker.uid).inspect
#    puts "plurk_id to permalink: " + plurker.get_permalink(4183588).inspect #should be http://www.plurk.com/p/2ho2s
#    puts "permalink to plurk_id: " + plurker.permalink_to_plurk_id("http://www.plurk.com/p/2ho2s").inspect #should be 4183588
  end
end