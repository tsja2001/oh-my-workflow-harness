import com.alibaba.fastjson.*;
import java.util.*;

/** 验证 getJsonPath 的三种改法，返回的是不是"同一个对象"（同一性决定按钮能不能写回去） */
public class Ident {
    static void p(String id, Object v){ System.out.println(id+"|"+v); }

    @SuppressWarnings("unchecked")
    static <T> T variantHistoric(JSONObject source, String path, Class<T> returnClass){
        Object g = source.get(path);
        if (g instanceof JSON) { return JSONObject.toJavaObject((JSON) g, returnClass); }
        return (T) g;
    }
    @SuppressWarnings("unchecked")
    static <T> T variantIsInstance(JSONObject source, String path, Class<T> returnClass){
        Object g = source.get(path);
        if (returnClass != null && returnClass.isInstance(g)) { return (T) g; }
        return JSONObject.toJavaObject((JSON) g, returnClass);
    }

    public static void main(String[] a){
        // 复刻 transferArray 的真实结构： { data: { root: [ {...}, {...} ] } }
        JSONObject row = new JSONObject(); row.put("code","C1"); row.put("t", new Date(1780000000000L));
        JSONArray root = new JSONArray(); root.add(row);
        JSONObject data = new JSONObject(); data.put("root", root);
        JSONObject target = new JSONObject(); target.put("data", data);

        // ---- 历史改法 ----
        JSONArray k1 = variantHistoric(data, "root", JSONArray.class);
        p("H1-返回是同一个JSONArray实例", (k1 == root));
        JSONObject e1 = k1.getJSONObject(0);
        p("H2-元素是同一个JSONObject实例", (e1 == row));
        e1.put("operList", "BTN-H");
        p("H3-写回后原结构里能看到吗", target.getJSONObject("data").getJSONArray("root").getJSONObject(0).get("operList"));
        p("H4-元素里日期类型", String.valueOf(e1.get("t")==null?null:e1.get("t").getClass().getName()));

        // 清理
        row.remove("operList");

        // ---- isInstance 改法 ----
        JSONArray k2 = variantIsInstance(data, "root", JSONArray.class);
        p("I1-返回是同一个JSONArray实例", (k2 == root));
        JSONObject e2 = k2.getJSONObject(0);
        p("I2-元素是同一个JSONObject实例", (e2 == row));
        e2.put("operList", "BTN-I");
        p("I3-写回后原结构里能看到吗", target.getJSONObject("data").getJSONArray("root").getJSONObject(0).get("operList"));
        p("I4-元素里日期类型", String.valueOf(e2.get("t")==null?null:e2.get("t").getClass().getName()));

        // ---- getJSONObject 本身是否返回同一实例（transferArray 里用了 k.getJSONObject(i)） ----
        p("X1-JSONArray.getJSONObject(0)是同一实例", (root.getJSONObject(0) == row));
        // ---- 单对象分支：new HashMap<>(jsonObject) 保类型 ----
        Map<String,Object> m = new HashMap<>(row);
        p("X2-HashMap浅拷贝里日期类型", String.valueOf(m.get("t").getClass().getName()));
    }
}
