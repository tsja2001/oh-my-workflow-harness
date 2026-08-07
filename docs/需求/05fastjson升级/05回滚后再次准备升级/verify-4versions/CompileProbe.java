import com.alibaba.fastjson.*;
import com.alibaba.fastjson.util.TypeUtils;
import com.alibaba.fastjson.serializer.SerializerFeature;
import java.util.*;

// 用代码库里真实出现的调用形态逐个试编译
public class CompileProbe {
    static class Bean { public String a; public Date d; }

    public static void main(String[] x) {
        Bean b = new Bean();
        String s = "{\"a\":1}";

        // ---- 组1：JSONObject 作为静态入口（代码里 121+129 处这么写）----
        Object o1 = JSONObject.parseObject(s);            // #G1
        Object o2 = JSONObject.parseObject(s, Bean.class);// #G2
        String  o3 = JSONObject.toJSONString(b);          // #G3
        Object o4 = JSONObject.parseArray(s);             // #G4
        Object o5 = JSONObject.toJSON(b);                 // #G5
        byte[] o6 = JSONObject.toJSONBytes(b);            // #G6
        Object o7 = JSONObject.parse(s);                  // #G7
        Object o8 = JSONArray.parseArray(s);              // #G8
        String o9 = JSONArray.toJSONString(b);            // #G9

        // ---- 组2：常规 JSON 静态 ----
        String a1 = JSON.toJSONString(b);
        String a2 = JSON.toJSONString(b, SerializerFeature.WriteMapNullValue);
        Bean   a3 = JSON.parseObject(s, Bean.class);
        JSONObject a4 = JSON.parseObject(s);
        List<Bean> a5 = JSON.parseArray(s, Bean.class);
        JSONArray  a6 = JSON.parseArray(s);
        Object a7 = JSON.parse(s);
        Object a8 = JSON.toJSON(b);
        byte[] a9 = JSON.toJSONBytes(b, SerializerFeature.WriteMapNullValue);
        Bean  a10 = JSON.toJavaObject((JSON) a4, Bean.class);

        // ---- 组3：实例方法 ----
        JSONObject jo = new JSONObject();
        Bean  b1 = jo.toJavaObject(Bean.class);
        Map<String,Object> b2 = jo.toJavaObject(new TypeReference<Map<String,Object>>(){});
        JSONObject b3 = jo.getJSONObject("k");
        JSONArray  b4 = jo.getJSONArray("k");
        Date       b5 = jo.getDate("k");
        Integer    b6 = jo.getInteger("k");
        String     b7 = jo.getString("k");
        java.math.BigDecimal b8 = jo.getBigDecimal("k");
        Boolean    b9 = jo.getBoolean("k");
        Long      b10 = jo.getLong("k");

        // ---- 组4：类型关系（1.x 里 JSONObject extends JSON）----
        JSON asJson = (JSON) jo;                          // #G10 强转
        boolean isJson = (jo instanceof JSON);            // #G11

        // ---- 组5：JSONValidator / JSONPObject（代码里有用）----
        JSONValidator v = JSONValidator.from(s);
        boolean valid = v.validate();
        JSONValidator.Type t = v.getType();
        JSONPObject p = new JSONPObject("cb");

        // ---- 组6：已知会消失的 API（预期在 2.x 编译失败）----
        Class<?> c = TypeUtils.getClassFromMapping("java.lang.String");   // #G12 预期 2.x 挂

        System.out.println("compile-ok");
    }
}
