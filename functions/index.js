"use strict";

const admin = require("firebase-admin");
const {defineSecret} = require("firebase-functions/params");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");

admin.initializeApp();

const broadcastAdminUids = defineSecret("BROADCAST_ADMIN_UIDS");

async function updateBroadcastStatus(snapshot, broadcastId, fields) {
  const batch = admin.firestore().batch();
  batch.update(snapshot.ref, fields);
  batch.set(
      admin.firestore().collection("adminNotifications").doc(broadcastId),
      fields,
      {merge: true},
  );
  await batch.commit();
}

exports.sendBroadcastPush = onDocumentCreated({
  document: "broadcasts/{broadcastId}",
  region: "us-central1",
  retry: true,
  secrets: [broadcastAdminUids],
}, async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const data = snapshot.data();
  const allowedUids = new Set(
      broadcastAdminUids.value().split(",").map((uid) => uid.trim()).filter(Boolean),
  );
  const senderUid = typeof data.sentBy === "string" ? data.sentBy : "";

  if (!allowedUids.has(senderUid)) {
    await updateBroadcastStatus(snapshot, event.params.broadcastId, {
      pushStatus: "rejected",
      pushError: "Sender is not authorized to send broadcasts.",
    });
    logger.warn("Rejected broadcast from an unauthorized sender", {
      broadcastId: event.params.broadcastId,
    });
    return;
  }

  const target = typeof data.target === "string" ? data.target : "all_users";
  if (!/^[a-zA-Z0-9-_.~%]{1,900}$/.test(target)) {
    await updateBroadcastStatus(snapshot, event.params.broadcastId, {
      pushStatus: "rejected",
      pushError: "Invalid FCM topic.",
    });
    return;
  }

  const title = typeof data.title === "string" ? data.title.trim() : "";
  const body = typeof data.body === "string" ? data.body.trim() : "";
  if (!title || title.length > 200 || body.length > 2000) {
    await updateBroadcastStatus(snapshot, event.params.broadcastId, {
      pushStatus: "rejected",
      pushError: "Notification title or message is invalid.",
    });
    return;
  }

  try {
    const messageId = await admin.messaging().send({
      topic: target,
      notification: {title, body},
      data: {broadcastId: event.params.broadcastId},
      android: {
        priority: "high",
        notification: {
          channelId: "route_master_notifications",
          color: "#0F766E",
          icon: "ic_notification",
        },
      },
      apns: {
        payload: {
          aps: {sound: "default"},
        },
      },
    });
    await updateBroadcastStatus(snapshot, event.params.broadcastId, {
      pushStatus: "sent",
      pushMessageId: messageId,
      pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
      pushError: admin.firestore.FieldValue.delete(),
    });
    logger.info("Broadcast push sent", {
      broadcastId: event.params.broadcastId,
      target,
      messageId,
    });
  } catch (error) {
    await updateBroadcastStatus(snapshot, event.params.broadcastId, {
      pushStatus: "failed",
      pushError: typeof error.code === "string" ? error.code : "send-failed",
    });
    logger.error("Broadcast push failed", {
      broadcastId: event.params.broadcastId,
      error,
    });
    throw error;
  }
});
