import com.pcitc.scm.common.json.JsonTransferUtil;   // ← 真实那个改过的公司工具类
import com.alibaba.fastjson.JSONObject;
import com.alibaba.fastjson.TypeReference;

import java.util.Date;
import java.util.Map;

/**
 * 直接测“本次修改的功能”：调用真实的 JsonTransferUtil.toResolverMap，
 * 验证日期不再被转坏、数字/字符串/对象不被误伤，并顺带复现旧写法的 bug 作对照。
 */
public class ToResolverMapTest {
    static int pass = 0, fail = 0;
    static void check(String name, boolean ok) {
        System.out.println((ok ? "  [PASS] " : "  [FAIL] ") + name);
        if (ok) pass++; else fail++;
    }

    public static void main(String[] args) {
        // 构造贴近真实的一行：日期 + 数字 + 字符串 + 嵌套对象
        JSONObject row = new JSONObject();
        row.put("sourceSignEndTime", new Date());
        row.put("needQual", Integer.valueOf(1));
        row.put("state", "080");
        JSONObject nested = new JSONObject(); nested.put("x", Integer.valueOf(9));
        row.put("nested", nested);

        System.out.println("== 测试本次新增方法 JsonTransferUtil.toResolverMap ==");
        Map<String, Object> m = JsonTransferUtil.toResolverMap(row);
        check("日期保持 Date 类型", m.get("sourceSignEndTime") instanceof Date);
        boolean castOk;
        try { Date d = (Date) m.get("sourceSignEndTime"); castOk = (d != null); }
        catch (Exception e) { castOk = false; }
        check("(Date) 强转不再报 ClassCastException", castOk);
        check("数字保持 Integer 类型", m.get("needQual") instanceof Integer);
        check("字符串保持 String 类型", m.get("state") instanceof String);
        check("嵌套对象仍是对象(Map)", m.get("nested") instanceof Map);
        check("null 入参安全返回空 Map（不抛空指针）", JsonTransferUtil.toResolverMap(null) != null);

        System.out.println("\n== 对照：旧写法 toJavaObject(TypeReference<Map>)（升级后会坏） ==");
        Map<String, Object> old = row.toJavaObject(new TypeReference<Map<String, Object>>() {});
        check("旧写法把日期变成了 String（复现线上 bug）", old.get("sourceSignEndTime") instanceof String);

        System.out.println("\n结果：通过 " + pass + " 项 / 失败 " + fail + " 项");
        if (fail > 0) System.exit(1);
        System.out.println(">>> 本次修改功能验证：全部通过");
    }
}
