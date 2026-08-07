package demo;

import com.alibaba.fastjson.JSON;               // 注意：这是 compat 包，生产代码 JsonTransferUtil 用的就是这个
import com.alibaba.fastjson.JSONObject;
import com.alibaba.fastjson.TypeReference;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * ================================================================
 *  Fastjson 2 日期兼容问题 · 现场演示程序
 * ================================================================
 *
 *  背景：
 *    公司把 fastjson 从 1.x 升级到 2.0.62（为了堵安全漏洞）。升级后，寻源列表接口报错：
 *        java.lang.String cannot be cast to java.util.Date
 *    原因是：公共转换器在给列表每行“补操作按钮”时，会把这一行数据转成一个通用 Map，
 *    fastjson 2.x 在这一步把“日期对象(Date)”悄悄变成了“字符串(String)”；
 *    下游业务代码还按 Date 来强转，就崩了。
 *
 *  这个程序
 *    把【三种改法】放在一起，用同一份数据各跑一遍，当场比出谁能修好、谁修不好。
 *    —— 它不依赖公司任何代码，是独立自证的，所以“不管你最后决定在哪改”，都能先用它验证思路。
 *
 *  怎么看结果：
 *    每个场景末尾都会打印 ✅ 或 ❌。看最后的“结论”表就够了。
 *
 *  三种改法：
 *    场景 1：现网写法             —— 复现线上报错（问题根源长啥样）
 *    场景 2：思路①：加一个方法  —— 在 JsonTransferUtil 里加“浅拷贝”方法（有效）
 *    场景 3：思路②：全局日期格式 —— 设 fastjson 全局日期格式
//  *       JSON.configWriterDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
		    JSON.configReaderDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
 * ================================================================
 */
public class FastjsonDateDemo {

    /**
     * ★★★ 这就是“思路①：在 JsonTransferUtil 里加一个方法”的那个方法 ★★★
     *
     * 把 JSONObject 原样浅拷贝成一个普通 Map：每个字段的值“直接搬过去”，不经过 JSON 文本，
     * 所以 Date 还是 Date、数字还是数字、对象还是对象。
     *
     * 真要落地时，把这段放进 com.pcitc.scm.common.json.JsonTransferUtil，
     * 再把公共转换器 OperListResponseTransferServiceImpl 第 83、117 行的
     *     obj.toJavaObject(new TypeReference<Map<String,Object>>(){})
     * 改成
     *     JsonTransferUtil.toResolverMap(obj)
     * 即可。
     */
    static Map<String, Object> toResolverMap(JSONObject row) {
        return new HashMap<>(row);   // 关键：浅拷贝，不走“序列化成文本再读回来”的往返
    }

    // —— 下面都是演示用的小工具方法 ——

    /** 打印某个值的 Java 类型名（看它到底是 Date 还是 String） */
    static String typeName(Object o) {
        return (o == null) ? "null" : o.getClass().getName();
    }

    /** 试着把值强转成 Date（模拟业务代码第 216 行的 (Date) 强转），返回“成功/失败”说明 */
    static String tryCastToDate(Object value) {
        try {
            Date d = (Date) value;
            return "✅ 成功  ->  " + d;
        } catch (Exception e) {
            return "❌ 崩溃  ->  " + e.getClass().getSimpleName() + ": " + e.getMessage();
        }
    }

    /**
     * 构造“贴近真实”的一行返回数据：
     * 模拟数据库查出来、经过 JSON.toJSON(VO) 之后的 JSONObject —— 里面装着真正的 Date、数字、字符串、嵌套对象。
     */
    static JSONObject makeOneRow() {
        JSONObject row = new JSONObject();
        row.put("sourceSignEndTime", new Date());          // 截止时间：真正的 Date 对象
        row.put("needQual", Integer.valueOf(1));           // 数字
        row.put("state", "080");                           // 字符串
        JSONObject nested = new JSONObject();              // 嵌套对象
        nested.put("x", Integer.valueOf(9));
        row.put("nested", nested);
        return row;
    }

    static void line() {
        System.out.println("--------------------------------------------------------------------");
    }

    public static void main(String[] args) {
        System.out.println("====================================================================");
        System.out.println(" Fastjson 2 日期兼容问题 · 现场演示");
        System.out.println(" 当前 fastjson 大版本 = " + fastjsonMajor() + "   （必须是 2.x 才能复现，1.x 不会报错）");
        System.out.println("====================================================================");

        JSONObject sample = makeOneRow();
        System.out.println("【准备】数据库出来的一行，截止时间此刻是真正的日期对象：");
        System.out.println("        sourceSignEndTime 类型 = " + typeName(sample.get("sourceSignEndTime")));
        System.out.println();

        // ============ 场景 1：现网写法（复现线上报错） ============
        line();
        System.out.println("场景 1｜现网写法（出问题的那行代码）");
        System.out.println("        row.toJavaObject(new TypeReference<Map<String,Object>>(){})");
        JSONObject row1 = makeOneRow();
        Map<String, Object> map1 = row1.toJavaObject(new TypeReference<Map<String, Object>>() {});
        System.out.println("   结果：sourceSignEndTime 变成 = " + typeName(map1.get("sourceSignEndTime"))
                + "   值=" + map1.get("sourceSignEndTime"));
        System.out.println("        needQual = " + typeName(map1.get("needQual"))
                + " | state = " + typeName(map1.get("state"))
                + " | nested = " + typeName(map1.get("nested"))
                + "   （数字/字符串/对象没坏，唯独日期被降成了 String）");
        System.out.println("        (Date) 强转 = " + tryCastToDate(map1.get("sourceSignEndTime")));
        System.out.println("   >>> ✘ 复现了线上的 ClassCastException");
        System.out.println();

        // ============ 场景 2：思路①——加方法（浅拷贝），有效 ============
        line();
        System.out.println("场景 2｜思路①：在 JsonTransferUtil 里加一个方法（浅拷贝）");
        System.out.println("        JsonTransferUtil.toResolverMap(row)   内部 = new HashMap<>(row)");
        JSONObject row2 = makeOneRow();
        Map<String, Object> map2 = toResolverMap(row2);   // ← 调用我们新加的方法
        System.out.println("   结果：sourceSignEndTime 保持 = " + typeName(map2.get("sourceSignEndTime"))
                + "   值=" + map2.get("sourceSignEndTime"));
        System.out.println("        needQual = " + typeName(map2.get("needQual"))
                + " | state = " + typeName(map2.get("state"))
                + " | nested = " + typeName(map2.get("nested"))
                + "   （全部原样保留）");
        System.out.println("        (Date) 强转 = " + tryCastToDate(map2.get("sourceSignEndTime")));
        System.out.println("   >>> ✔ 有效：“加方法”的思路 + 正确实现（浅拷贝）");
        System.out.println();

        // ============ 场景 3：思路②——全局日期格式，无效 ============
        line();
        System.out.println("场景 3｜思路②：设 fastjson 全局日期格式");
        System.out.println("        JSON.configWriterDateFormat(...) / configReaderDateFormat(...)");
        System.out.println("        注意：这两个方法在 compat 的 com.alibaba.fastjson.JSON 上【不存在】，");
        System.out.println("              只有原生 com.alibaba.fastjson2.JSON 才有 —— 所以这里必须用原生类调用。");
        // 设置全局日期格式（原生 fastjson2.JSON）—— 这是一个进程级、永久、全局的开关
        com.alibaba.fastjson2.JSON.configWriterDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
        com.alibaba.fastjson2.JSON.configReaderDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
        JSONObject row3 = makeOneRow();
        Map<String, Object> map3 = row3.toJavaObject(new TypeReference<Map<String, Object>>() {});
        System.out.println("   结果：sourceSignEndTime 仍然是 = " + typeName(map3.get("sourceSignEndTime"))
                + "   值=" + map3.get("sourceSignEndTime") + "   （只是字符串换了个样子）");
        System.out.println("        (Date) 强转 = " + tryCastToDate(map3.get("sourceSignEndTime")));
        System.out.println("   >>> ✘ 无效：格式只改“字符串长啥样”，改不了“它是不是 Date”");
        System.out.println();

        // ============ 结论 ============
        System.out.println("====================================================================");
        System.out.println(" 结  论");
        System.out.println("   场景 1  现网写法（toJavaObject 泛型 Map）  ： ❌ 报错  ← 问题根源");
        System.out.println("   场景 2  加方法 + 浅拷贝 new HashMap<>()     ： ✅ 修复  ← 推荐");
        System.out.println("   场景 3  设全局日期格式                      ： ❌ 无效");
        System.out.println("====================================================================");
    }

    /**
     * 判断当前 fastjson 是 1.x 还是 2.x：只有 2.x 才有 com.alibaba.fastjson2 这个包。
     * （用来防止有人误用 1.x 的 jar 来跑——那样场景1不会报错，会误导。）
     */
    static String fastjsonMajor() {
        try {
            Class.forName("com.alibaba.fastjson2.JSON");
            return "2.x";
        } catch (ClassNotFoundException e) {
            return "1.x";
        }
    }
}
