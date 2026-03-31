import { useEffect, useRef, useState, useCallback } from 'react';
import {
  Stage,
  LocalStageStream,
  SubscribeType,
  StageEvents,
  StageConnectionState,
  StreamType,
} from 'amazon-ivs-web-broadcast';
import type {
  StageStrategy,
  StageParticipantInfo,
} from 'amazon-ivs-web-broadcast';

interface ParticipantEntry {
  info: StageParticipantInfo;
  streams: { mediaStreamTrack: MediaStreamTrack; streamType: string }[];
}

interface IVSRealTimeProps {
  token: string;
}

function ParticipantVideo({
  entry,
}: {
  entry: ParticipantEntry;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const audioRef = useRef<HTMLAudioElement>(null);

  useEffect(() => {
    const videoTracks = entry.streams
      .filter((s) => s.streamType === StreamType.VIDEO)
      .map((s) => s.mediaStreamTrack);

    const audioTracks = entry.info.isLocal
      ? []
      : entry.streams
          .filter((s) => s.streamType === StreamType.AUDIO)
          .map((s) => s.mediaStreamTrack);

    if (videoRef.current && videoTracks.length > 0) {
      videoRef.current.srcObject = new MediaStream(videoTracks);
    }
    if (audioRef.current && audioTracks.length > 0) {
      audioRef.current.srcObject = new MediaStream(audioTracks);
    }

    return () => {
      if (videoRef.current) videoRef.current.srcObject = null;
      if (audioRef.current) audioRef.current.srcObject = null;
    };
  }, [entry.streams, entry.info.isLocal]);

  return (
    <div className="rt-participant">
      <video ref={videoRef} autoPlay playsInline muted />
      {!entry.info.isLocal && <audio ref={audioRef} autoPlay />}
      <span className="rt-participant-label">
        {entry.info.isLocal ? 'You' : entry.info.userId || entry.info.id}
      </span>
    </div>
  );
}

export default function IVSRealTime({ token }: IVSRealTimeProps) {
  const stageRef = useRef<Stage | null>(null);
  const localStreamsRef = useRef<LocalStageStream[]>([]);
  const [participants, setParticipants] = useState<Map<string, ParticipantEntry>>(new Map());
  const [connectionState, setConnectionState] = useState<string>('disconnected');
  const [error, setError] = useState<string | null>(null);

  const strategyRef = useRef<StageStrategy>({
    stageStreamsToPublish() {
      return localStreamsRef.current;
    },
    shouldPublishParticipant() {
      return true;
    },
    shouldSubscribeToParticipant() {
      return SubscribeType.AUDIO_VIDEO;
    },
  });

  const join = useCallback(async () => {
    if (!token) {
      setError('No stage participant token provided. Add VITE_IVS_STAGE_TOKEN to .env');
      return;
    }

    setError(null);

    try {
      const media = await navigator.mediaDevices.getUserMedia({
        video: { width: { max: 1280 }, height: { max: 720 } },
        audio: true,
      });

      const cameraStream = new LocalStageStream(media.getVideoTracks()[0]);
      const micStream = new LocalStageStream(media.getAudioTracks()[0]);
      localStreamsRef.current = [cameraStream, micStream];

      const stage = new Stage(token, strategyRef.current);
      stageRef.current = stage;

      stage.on(StageEvents.STAGE_CONNECTION_STATE_CHANGED, (state: StageConnectionState) => {
        setConnectionState(state);
        if (state === StageConnectionState.ERRORED) {
          setError('Stage connection error');
        }
      });

      stage.on(
        StageEvents.STAGE_PARTICIPANT_STREAMS_ADDED,
        (participant: StageParticipantInfo, streams: { mediaStreamTrack: MediaStreamTrack; streamType: string }[]) => {
          setParticipants((prev) => {
            const next = new Map(prev);
            const existing = next.get(participant.id);
            next.set(participant.id, {
              info: participant,
              streams: [...(existing?.streams ?? []), ...streams],
            });
            return next;
          });
        },
      );

      stage.on(
        StageEvents.STAGE_PARTICIPANT_STREAMS_REMOVED,
        (participant: StageParticipantInfo, streams: { mediaStreamTrack: MediaStreamTrack; streamType: string; id?: string }[]) => {
          setParticipants((prev) => {
            const next = new Map(prev);
            const existing = next.get(participant.id);
            if (existing) {
              const removedTracks = new Set(streams.map((s) => s.mediaStreamTrack.id));
              const remaining = existing.streams.filter(
                (s) => !removedTracks.has(s.mediaStreamTrack.id),
              );
              if (remaining.length === 0) {
                next.delete(participant.id);
              } else {
                next.set(participant.id, { info: participant, streams: remaining });
              }
            }
            return next;
          });
        },
      );

      stage.on(StageEvents.STAGE_PARTICIPANT_LEFT, (participant: StageParticipantInfo) => {
        setParticipants((prev) => {
          const next = new Map(prev);
          next.delete(participant.id);
          return next;
        });
      });

      await stage.join();
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (message.includes('Permission denied') || message.includes('NotAllowedError')) {
        setError('Camera/microphone access denied. Allow permissions and try again.');
      } else {
        setError(message);
      }
    }
  }, [token]);

  const leave = useCallback(() => {
    stageRef.current?.leave();
    stageRef.current = null;

    localStreamsRef.current.forEach((s) => {
      s.mediaStreamTrack.stop();
    });
    localStreamsRef.current = [];

    setParticipants(new Map());
    setConnectionState('disconnected');
  }, []);

  useEffect(() => {
    return () => {
      stageRef.current?.leave();
      localStreamsRef.current.forEach((s) => s.mediaStreamTrack.stop());
    };
  }, []);

  const isConnected = connectionState === StageConnectionState.CONNECTED;
  const isConnecting = connectionState === StageConnectionState.CONNECTING;

  return (
    <div className="rt-container">
      <div className="rt-toolbar">
        <div className="rt-status">
          <span
            className={`rt-status-dot ${isConnected ? 'connected' : ''} ${isConnecting ? 'connecting' : ''}`}
          />
          <span className="rt-status-text">
            {isConnected && 'Connected'}
            {isConnecting && 'Connecting…'}
            {!isConnected && !isConnecting && 'Disconnected'}
          </span>
        </div>
        {!isConnected && !isConnecting ? (
          <button className="rt-join-btn" onClick={join} disabled={!token}>
            Join Stage
          </button>
        ) : (
          <button className="rt-leave-btn" onClick={leave}>
            Leave Stage
          </button>
        )}
      </div>

      {error && (
        <div className="rt-error">
          <p>{error}</p>
        </div>
      )}

      {participants.size > 0 ? (
        <div className={`rt-grid rt-grid-${Math.min(participants.size, 4)}`}>
          {Array.from(participants.values()).map((entry) => (
            <ParticipantVideo key={entry.info.id} entry={entry} />
          ))}
        </div>
      ) : (
        <div className="rt-empty">
          {isConnected ? (
            <p>Waiting for other participants to join…</p>
          ) : (
            <>
              <p>IVS Real-Time Stage</p>
              <p className="rt-empty-hint">
                Click <strong>Join Stage</strong> to connect your camera and microphone
              </p>
            </>
          )}
        </div>
      )}
    </div>
  );
}
