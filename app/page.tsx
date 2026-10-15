import { getChatGPTUser } from "./chatgpt-auth";
import Academy from "./academy";
export const dynamic = "force-dynamic";
export default async function Home() {
  const user = await getChatGPTUser();
  return (
    <Academy user={user ? { id: user.userId, name: user.displayName } : null} />
  );
}
