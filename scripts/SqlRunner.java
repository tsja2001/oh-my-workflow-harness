import java.sql.*;
import java.nio.file.*;

/**
 * 无 mysql 客户端时的查库回退工具（由 scripts/dbq.sh 调用）。
 * 连接信息从环境变量取：DB_HOST/DB_USER/DB_PASS/DB_NAME（dbq.sh 已从 ai-docs/creds.env source 并导出）。
 */
public class SqlRunner {
  public static void main(String[] args) throws Exception {
    if (args.length < 1) throw new IllegalArgumentException("sql file required");
    String host = System.getenv("DB_HOST");
    String user = System.getenv("DB_USER");
    String pass = System.getenv("DB_PASS");
    String db = System.getenv("DB_NAME");
    if (db == null) db = "";
    String sql = new String(Files.readAllBytes(Paths.get(args[0])), "UTF-8").trim();
    if (sql.endsWith(";")) sql = sql.substring(0, sql.length() - 1);
    String url = "jdbc:mysql://" + host + ":3306/" + db + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai&characterEncoding=utf8&useUnicode=true&connectTimeout=8000";
    Class.forName("com.mysql.cj.jdbc.Driver");
    try (Connection c = DriverManager.getConnection(url, user, pass); Statement s = c.createStatement()) {
      boolean has = s.execute(sql);
      if (!has) {
        System.out.println("updateCount=" + s.getUpdateCount());
        return;
      }
      try (ResultSet rs = s.getResultSet()) {
        ResultSetMetaData md = rs.getMetaData();
        int cols = md.getColumnCount();
        for (int i = 1; i <= cols; i++) {
          if (i > 1) System.out.print("\t");
          System.out.print(md.getColumnLabel(i));
        }
        System.out.println();
        int rows = 0;
        while (rs.next() && rows < 500) {
          for (int i = 1; i <= cols; i++) {
            if (i > 1) System.out.print("\t");
            Object v = rs.getObject(i);
            System.out.print(v == null ? "NULL" : String.valueOf(v).replace('\n', ' '));
          }
          System.out.println();
          rows++;
        }
      }
    }
  }
}
