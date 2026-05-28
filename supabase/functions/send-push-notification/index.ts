import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { SignJWT, importPKCS8 } from "npm:jose@5.9.6";

interface Device {
  token: string;
  platform: string;
}

interface PushPayload {
  type: "message" | "call" | "missed_call" | "invitation" | "post_like" | "post_comment" | "comment_like" | "comment_reply";
  recipient_id: string;
  sender_id?: string;
  sender_name?: string;
  content?: string;
  call_type?: string;
  call_id?: string;
  invitation_id?: string;
  message_id?: string;
  devices: Device[];
  caller_name?: string;
  group_name?: string;
  channel_id?: string;
  team_id?: string;
  squad_id?: string;
}

interface ServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string;
}

let cachedToken: { accessToken: string; expiresAt: number } | null = null;

function parseServiceAccount(raw: string): ServiceAccount {
  return JSON.parse(raw);
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  if (cachedToken && Date.now() < cachedToken.expiresAt) {
    return cachedToken.accessToken;
  }

  const now = Math.floor(Date.now() / 1000);
  const jwtPayload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri,
    exp: now + 3600,
    iat: now,
  };

  const privateKey = await importPKCS8(sa.private_key, "RS256");
  const assertion = await new SignJWT(jwtPayload)
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .sign(privateKey);

  const tokenResponse = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!tokenResponse.ok) {
    const err = await tokenResponse.text();
    console.error("OAuth2 error:", tokenResponse.status, err);
    throw new Error(`OAuth2 token error: ${tokenResponse.status} ${err}`);
  }

  const data = await tokenResponse.json();
  const expiresAt = Date.now() + (data.expires_in - 60) * 1000;
  cachedToken = { accessToken: data.access_token, expiresAt };
  return data.access_token;
}

function buildFcmV1Message(
  token: string,
  type: string,
  title: string,
  body: string,
  data: Record<string, string>,
) {
  const channelId = type === "call" ? "incoming_calls_channel" : "messages_channel";
  // Tell Firebase SDK to use notification ID 1001 for calls so
  // FCM system notification shares tag+id with local notifications
  // → they replace each other seamlessly (no duplicate).
  if (type === "call") {
    data["gcm.n.notification_id"] = "1001";
  }
  const msg: Record<string, unknown> = {
    token,
    notification: { title, body },
    data,
    android: {
      priority: "high",
      notification: {
        channel_id: channelId,
        sound: "default",
        ...(type === "call" ? { tag: "incoming_call" } : {}),
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          "content-available": 1,
        },
      },
    },
  };

  return { message: msg };
}

function buildNotification(payload: PushPayload): { title: string; body: string; data: Record<string, string> } {
  const data: Record<string, string> = { type: payload.type };

  switch (payload.type) {
    case "message":
      data["sender_id"] = payload.sender_id ?? "";
      data["sender_name"] = payload.sender_name ?? "";
      data["message_id"] = payload.message_id ?? "";
      data["content"] = payload.content ?? "";
      const senderName = payload.sender_name ?? "Someone";
      return { title: senderName, body: payload.content ?? "", data };
    case "call":
      data["call_id"] = payload.call_id ?? "";
      data["caller_id"] = payload.caller_id ?? payload.sender_id ?? "";
      data["call_type"] = payload.call_type ?? "audio";
      data["caller_name"] = payload.caller_name ?? "Someone";
      const typeLabel = payload.call_type === "video" ? "video" : "audio";
      const groupName = payload.group_name ?? "";
      const callerName = payload.caller_name ?? "Someone";
      return {
        title: groupName ? `${callerName} (${groupName})` : callerName,
        body: `Incoming ${typeLabel} call`,
        data,
      };
    case "missed_call":
      data["caller_id"] = payload.caller_id ?? "";
      data["caller_name"] = payload.caller_name ?? "";
      data["call_id"] = payload.call_id ?? "";
      const missedCallerName = payload.caller_name ?? "Someone";
      return { title: "Missed call", body: `from ${missedCallerName}`, data };
    case "invitation":
      data["sender_id"] = payload.sender_id ?? "";
      data["invitation_id"] = payload.invitation_id ?? "";
      return { title: "New invitation", body: "You received a new invitation", data };
    case "post_like":
    case "post_comment":
    case "comment_like":
    case "comment_reply":
      data["sender_id"] = payload.sender_id ?? "";
      data["sender_name"] = payload.sender_name ?? "";
      data["content"] = payload.content ?? "";
      const actor = payload.sender_name ?? "Someone";
      return { title: actor, body: payload.content ?? "", data };
  }
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!saRaw) {
    console.error("FCM_SERVICE_ACCOUNT not set");
    return new Response("Server configuration error", { status: 500 });
  }

  try {
    const payload: PushPayload = await req.json();
    if (!payload.devices?.length) {
      return new Response("No devices", { status: 200 });
    }

    const sa = parseServiceAccount(saRaw);
    const accessToken = await getAccessToken(sa);
    const { title, body, data } = buildNotification(payload);

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    const results = await Promise.allSettled(
      payload.devices.map(async (d) => {
        const fcmBody = buildFcmV1Message(d.token, payload.type, title, body, data);
        const res = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(fcmBody),
        });
        if (!res.ok) {
          const errBody = await res.text();
          console.error(`FCM v1 send failed for token ${d.token.slice(0, 16)}...: ${res.status} ${errBody}`);
          throw new Error(`FCM error ${res.status}: ${errBody}`);
        }
      }),
    );

    const failures = results.filter((r) => r.status === "rejected").length;
    if (failures > 0) {
      console.error(`${failures}/${payload.devices.length} pushes failed`);
    }

    return new Response(
      JSON.stringify({ sent: payload.devices.length - failures, total: payload.devices.length }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("send-push-notification error:", e);
    return new Response("Internal error", { status: 500 });
  }
});
