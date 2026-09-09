import React from "react";
import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { loadFont as loadBricolage } from "@remotion/google-fonts/BricolageGrotesque";
import { loadFont as loadManrope } from "@remotion/google-fonts/Manrope";
import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";

const { fontFamily: bricolage } = loadBricolage("normal", {
  weights: ["700", "800"],
});
const { fontFamily: manrope } = loadManrope("normal", {
  weights: ["500", "600", "700", "800"],
});
const { fontFamily: mono } = loadMono("normal", { weights: ["400", "600"] });

// Tokens copiados de /Users/ricardomagana/clase-6to/index.html
const C = {
  ground: "#EEF1FA",
  ground2: "#E4EAF7",
  paper: "#FFFFFF",
  paperSoft: "#F7F9FE",
  ink: "#0C1846",
  inkSoft: "#3A4675",
  inkMute: "#6E79A6",
  line: "#DBE1F2",
  lineStrong: "#B9C3E1",
  school: "#1E3AAB",
  school2: "#3B5EF0",
  schoolTint: "#DDE4FF",
  lemon: "#F5DE3A",
  coral: "#D91F26",
  mint: "#35C89A",
};

// Bloque de texto falso para el periódico borroso al fondo.
const FakeParagraph: React.FC<{ lines: number; width?: string | number }> = ({
  lines,
  width = "100%",
}) => (
  <div style={{ width, display: "flex", flexDirection: "column", gap: 6 }}>
    {Array.from({ length: lines }).map((_, i) => (
      <div
        key={i}
        style={{
          height: 8,
          borderRadius: 3,
          background: i === lines - 1 ? C.lineStrong : C.line,
          width: i === lines - 1 ? "62%" : "100%",
          opacity: 0.9,
        }}
      />
    ))}
  </div>
);

const NewspaperBackground: React.FC = () => {
  return (
    <div
      style={{
        position: "absolute",
        inset: -80,
        background: C.paper,
        padding: 60,
        display: "grid",
        gridTemplateColumns: "1fr 1fr 1fr",
        gap: 28,
        transform: "rotate(-2deg) scale(1.05)",
      }}
    >
      {/* Cabecera del periódico */}
      <div
        style={{
          gridColumn: "1 / -1",
          borderTop: `4px solid ${C.ink}`,
          borderBottom: `2px solid ${C.ink}`,
          padding: "20px 0",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "baseline",
        }}
      >
        <div
          style={{
            fontFamily: bricolage,
            fontSize: 96,
            fontWeight: 800,
            color: C.ink,
            letterSpacing: -3,
          }}
        >
          Panamericano
        </div>
        <div
          style={{
            fontFamily: mono,
            fontSize: 22,
            color: C.inkSoft,
            letterSpacing: 2,
          }}
        >
          VOL. I · Nº 001
        </div>
      </div>

      {/* Columna 1 */}
      <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
        <div
          style={{
            fontFamily: bricolage,
            fontSize: 40,
            fontWeight: 800,
            color: C.ink,
            lineHeight: 1.05,
          }}
        >
          Los chismes que sacudieron la clase
        </div>
        <FakeParagraph lines={9} />
        <div
          style={{
            height: 220,
            background: `linear-gradient(135deg, ${C.schoolTint}, ${C.school})`,
            borderRadius: 6,
          }}
        />
        <FakeParagraph lines={7} />
      </div>

      {/* Columna 2 */}
      <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
        <div
          style={{
            fontFamily: mono,
            fontSize: 14,
            color: C.coral,
            letterSpacing: 2,
          }}
        >
          DEPORTES · LIGA LIPTON
        </div>
        <div
          style={{
            fontFamily: bricolage,
            fontSize: 46,
            fontWeight: 800,
            color: C.ink,
            lineHeight: 1.05,
          }}
        >
          Final de jornada: goleada histórica
        </div>
        <div
          style={{
            height: 260,
            background: `linear-gradient(160deg, ${C.lemon}, ${C.coral})`,
            borderRadius: 6,
          }}
        />
        <FakeParagraph lines={11} />
      </div>

      {/* Columna 3 */}
      <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
        <FakeParagraph lines={4} />
        <div
          style={{
            fontFamily: bricolage,
            fontSize: 34,
            fontWeight: 700,
            color: C.ink,
            lineHeight: 1.05,
          }}
        >
          Ranking de materias del weekly
        </div>
        <FakeParagraph lines={12} />
        <div
          style={{
            height: 160,
            background: `linear-gradient(135deg, ${C.mint}, ${C.school2})`,
            borderRadius: 6,
          }}
        />
        <FakeParagraph lines={6} />
      </div>
    </div>
  );
};

const Chip: React.FC<{
  label: string;
  color: string;
  bg: string;
  delay: number;
}> = ({ label, color, bg, delay }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({
    frame: frame - delay,
    fps,
    config: { damping: 14, stiffness: 130, mass: 0.7 },
  });
  return (
    <div
      style={{
        transform: `translateY(${(1 - p) * 24}px) scale(${0.85 + p * 0.15})`,
        opacity: p,
        padding: "12px 22px",
        borderRadius: 999,
        background: bg,
        color,
        fontFamily: mono,
        fontSize: 22,
        fontWeight: 600,
        letterSpacing: 1,
        textTransform: "uppercase",
        boxShadow: "0 4px 12px rgba(12,24,70,.08), 0 16px 30px rgba(12,24,70,.10)",
        border: `1.5px solid ${color}22`,
      }}
    >
      {label}
    </div>
  );
};

export const PeriodicoAnuncio: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // Background: fade in + subtle zoom out throughout
  const bgFade = interpolate(frame, [0, 20], [0, 1], {
    extrapolateRight: "clamp",
  });
  const bgScale = interpolate(frame, [0, durationInFrames], [1.15, 1.0]);
  const bgBlur = interpolate(frame, [0, 30], [24, 14], {
    extrapolateRight: "clamp",
  });

  // Título principal
  const titleP = spring({
    frame: frame - 12,
    fps,
    config: { damping: 20, stiffness: 90, mass: 0.9 },
  });

  // Kicker "MUY PRONTO"
  const kickerP = spring({
    frame: frame - 6,
    fps,
    config: { damping: 18, stiffness: 110 },
  });

  // Line details
  const lineP = spring({
    frame: frame - 22,
    fps,
    config: { damping: 22, stiffness: 100 },
  });

  // "COMING SOON" pulse (loop)
  const pulse = 0.5 + 0.5 * Math.sin((frame / fps) * Math.PI * 1.8);

  // Firma final
  const signatureP = spring({
    frame: frame - 30,
    fps,
    config: { damping: 24, stiffness: 90 },
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: C.ground,
        backgroundImage: [
          `radial-gradient(1100px 700px at 88% -10%, ${C.school}2E, transparent 60%)`,
          `radial-gradient(900px 600px at -10% 20%, ${C.coral}14, transparent 65%)`,
          `repeating-linear-gradient(0deg, transparent 0 31px, ${C.line} 31px 32px)`,
          `linear-gradient(180deg, ${C.ground} 0%, ${C.ground2} 100%)`,
        ].join(", "),
        fontFamily: manrope,
        color: C.ink,
        overflow: "hidden",
      }}
    >
      {/* Ligero shimmer del papel: sutil brillo animado del cuaderno */}
      <AbsoluteFill
        style={{
          background: `radial-gradient(700px 500px at 30% ${
            30 + Math.sin((frame / 30) * 0.6) * 8
          }%, ${C.paper}55, transparent 65%)`,
          opacity: bgFade * 0.9,
          mixBlendMode: "screen",
        }}
      />

      {/* Foreground content */}
      <AbsoluteFill
        style={{
          padding: 72,
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
        }}
      >
        {/* Top: escudo del 6to */}
        <div
          style={{
            display: "flex",
            justifyContent: "flex-start",
            alignItems: "flex-start",
          }}
        >
          <div
            style={{
              transform: `translateY(${(1 - kickerP) * -30}px) scale(${
                0.85 + kickerP * 0.15
              }) rotate(${(1 - kickerP) * 6}deg)`,
              opacity: kickerP,
              filter: "drop-shadow(0 12px 24px rgba(12,24,70,.25)) drop-shadow(0 4px 8px rgba(12,24,70,.15))",
            }}
          >
            <Img
              src={staticFile("escudo.png")}
              style={{ width: 340, height: "auto", display: "block" }}
            />
          </div>
        </div>

        {/* Middle: title block */}
        <div>
          <div
            style={{
              display: "inline-block",
              padding: "10px 20px",
              borderRadius: 999,
              background: C.coral,
              color: "#fff",
              fontFamily: mono,
              fontSize: 20,
              fontWeight: 600,
              letterSpacing: 4,
              transform: `translateY(${(1 - kickerP) * 20}px) scale(${
                0.9 + kickerP * 0.1
              })`,
              opacity: kickerP,
              marginBottom: 22,
              boxShadow: "0 10px 30px rgba(217,31,38,.3)",
            }}
          >
            ★ MUY PRONTO
          </div>
          <div
            style={{
              fontFamily: bricolage,
              fontSize: 128,
              fontWeight: 800,
              lineHeight: 0.92,
              letterSpacing: -4,
              color: C.ink,
              transform: `translateY(${(1 - titleP) * 40}px)`,
              opacity: titleP,
            }}
          >
            Periódico
            <br />
            <span
              style={{
                background: `linear-gradient(120deg, ${C.school}, ${C.school2} 55%, ${C.coral})`,
                WebkitBackgroundClip: "text",
                backgroundClip: "text",
                color: "transparent",
              }}
            >
              Panamericano
            </span>
          </div>
          <div
            style={{
              marginTop: 20,
              height: 4,
              width: `${lineP * 100}%`,
              maxWidth: 620,
              background: `linear-gradient(90deg, ${C.school}, ${C.coral})`,
              borderRadius: 4,
            }}
          />
          <div
            style={{
              marginTop: 22,
              fontFamily: manrope,
              fontSize: 30,
              fontWeight: 500,
              color: C.inkSoft,
              maxWidth: 780,
              transform: `translateY(${(1 - lineP) * 20}px)`,
              opacity: lineP,
              lineHeight: 1.35,
            }}
          >
            El diario oficial del <strong style={{ color: C.ink }}>6º grado</strong>
            . Historias, resultados y todo lo que pasa en clase — contado por
            nosotros.
          </div>
        </div>

        {/* Bottom: coming soon */}
        <div
          style={{
            transform: `translateY(${(1 - signatureP) * 30}px)`,
            opacity: signatureP,
          }}
        >
          <div
            style={{
              fontFamily: mono,
              fontSize: 20,
              color: C.inkMute,
              letterSpacing: 4,
              textTransform: "uppercase",
            }}
          >
            Primera edición
          </div>
          <div
            style={{
              fontFamily: bricolage,
              fontSize: 96,
              fontWeight: 800,
              color: C.ink,
              lineHeight: 1,
              marginTop: 10,
              letterSpacing: -3,
              opacity: 0.4 + 0.6 * pulse,
            }}
          >
            COMING SOON
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
