想做个自动登录获取token的功能，不用我再creds.env里手动粘贴了，然后你研究一下这个功能是配置成skill好，还是写一个脚本好，还是有什么其他合适的方式渠道。以及现在creds.env里面要不要增加字段，要的话你直接增加就行。，一切的目的就是为了让整个AI自动化开发的流程更流畅，体验更好，降本增效。

现在线上环境是这样的，分为招采平台和云采平台，每个平台又有test环境、uat环境、prod环境
每个环境下的招采和云采账号同步，token可以复用

test：
招采：http://10.0.54.16:32740/
云采：http://10.0.54.16:30370/
通用管理员 账号：10930002 密码：SSLLSX666&
供应商账号 账号：江苏鱼跃医疗设备股份有限公司 密码：SSLLSX666&


uat：
招采：http://10.0.54.16:31799/
云采：http://uat-yc.jdsn.cn/login/index.html#/

prod：
招采、云采 暂时先不去配置

test和uat登录时候只需要填用户名密码，图片验证码和短信验证码随便填就行不会校验

对于登录接口可以获取token

登录的curl：
fetch("http://10.0.54.16:32740/gateway/obs/business/auth/login/authUnity?t=1785834130747", {
  "headers": {
    "accept": "application/json, text/plain, */*",
    "accept-language": "zh-CN,zh;q=0.9,en;q=0.8,zh-TW;q=0.7",
    "content-type": "application/json",
    "cookie": "XXL_JOB_LOGIN_IDENTITY=7b226964223a312c22757365726e616d65223a2261646d696e222c2270617373776f7264223a223461316565363536643433613330373062643561373937383062653364343139222c22726f6c65223a312c227065726d697373696f6e223a6e756c6c7d; Hm_lvt_e4281b17375874e464dcdf70503a9aa0=1785295394,1785395754,1785503912,1785721206; Hm_lvt_558edd425f401ac150ffa184157b8f61=1785381207,1785459722,1785721145,1785809807; HMACCOUNT=C11F14A56302480E; token_type=bearer; Hm_lpvt_558edd425f401ac150ffa184157b8f61=1785834119",
    "Referer": "http://10.0.54.16:32740/"
  },
  "body": "{\"username\":\"10930002\",\"password\":\"dFqt6WU1NMTFNYNjY2Jg==7tK1E\",\"vCode\":\"1\",\"vCodeSign\":\"d9867afb3b96405b9422bdd920035b82\",\"phoneVCode\":\"1\",\"phoneVCodeSign\":\"\"}",
  "method": "POST"
});
