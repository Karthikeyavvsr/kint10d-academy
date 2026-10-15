import {
  integer,
  primaryKey,
  sqliteTable,
  text,
} from "drizzle-orm/sqlite-core";
export const progress = sqliteTable(
  "progress",
  {
    owner: text("owner").notNull(),
    key: text("key").notNull(),
    value: text("value").notNull(),
    revision: integer("revision").notNull().default(1),
    updated: text("updated").notNull(),
  },
  (t) => [primaryKey({ columns: [t.owner, t.key] })],
);
