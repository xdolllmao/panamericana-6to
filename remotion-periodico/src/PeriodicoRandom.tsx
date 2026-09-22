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
import { loadFont as loadPlayfair } from "@remotion/google-fonts/PlayfairDisplay";
import { loadFont as loadManrope } from "@remotion/google-fonts/Manrope";
import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";

const { fontFamily: serif } = loadPlayfair("normal", { weights: ["700", "800", "900"] });
const { fontFamily: sans } = loadManrope("normal", { weights: ["400", "500", "600", "700", "800"] });
const { fontFamily: mono } = loadMono("normal", { weights: ["400", "600"] });

// Paleta: papel periodico + tokens de la marca
const C = {
  paper: "#F4F1E8",
  paper2: "#EDE8DA",
  ink: "#141210",
  inkSoft: "#4A463E",
  inkMute: "#8A857A",
  rule: "#1A1712",
  school: "#1E3AAB",
  coral: "#C41E24",
  lemon: "#E6C200",
  mint: "#1E7A5F",
};

// ---- contenido random (generado una vez, deterministico por render) ----
const rand = (arr: string[], seed: number) => arr[seed % arr.length];

const LEADS = [
  "Escándalo en el lunch: desaparece el balón oficial",
  "Confirmado: el aire acondicionado volvió a fallar",
  "Alerta: profe deja tarea un viernes",
  "Insólito: alguien devolvió un lápiz que había prestado",
  "Última hora: se acabó la tinta de la pizarra",
];
const CHISMES = [
  "Dicen que en la B alguien trajo pupusas y no compartió.",
  "Rumores de romance entre dos secciones. Nadie confirma.",
  "Un squishy fue visto rebotando sin dueño en el pasillo.",
  "Se filtró que hay gira el lunes. O no. Nadie sabe.",
];
const DEPORTES = [
  "Equipo 1 gana otra vez y el 2 pide revancha.",
  "Iglesias mete gol y lo celebra tres días.",
  "Debate: ¿fue gol de poste o de cono?",
  "La Liga Lipton anuncia final épica en el break.",
];
const CLIMAS = ["Soleado con 90% de sueño", "Nublado con chance de examen", "Caluroso, traigan agua", "Fresco, ideal para dormir en clase"];
const HOROS = ["Hoy no confíes en tu grupo de mate", "Alguien te va a pedir la tarea", "Suerte en el recreo, cuidado en el quiz", "Es tu día: te toca pizarra"];
const SUERTE = ["07", "13", "21", "42", "69", "6to"];
const FACTS = [
  "El 82% de las promesas de 'te paso la tarea' no se cumplen.",
  "Un salón produce 3 chismes por minuto en promedio.",
  "El lápiz más prestado nunca vuelve. Es ley.",
  "Nadie sabe de quién es el suéter azul del perchero.",
];
const FILLER = "Lorem ipsum del salón: aquí iría info importante pero preferimos rellenar con misterio y suspenso escolar, porque las noticias serias aburren y este diario no.";

const FakeLines: React.FC<{ n: number; w?: string }> = ({ n, w = "100%" }) => (
  <div style={{ display: "flex", flexDirection: "column", gap: 5, width: w }}>
    {Array.from({ length: n }).map((_, i) => (
      <div key={i} style={{ height: 5, borderRadius: 2, background: C.inkMute, opacity: 0.35, width: i === n - 1 ? "55%" : "100%" }} />
    ))}
  </div>
);

const Rule: React.FC<{ p: number; h?: number }> = ({ p, h = 3 }) => (
  <div style={{ height: h, background: C.rule, width: `${p * 100}%`, borderRadius: 1 }} />
);

const Section: React.FC<{
  label: string;
  color: string;
  delay: number;
  children: React.ReactNode;
}> = ({ label, color, delay, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - delay, fps, config: { damping: 18, stiffness: 90 } });
  return (
    <div style={{ opacity: p, transform: `translateY(${(1 - p) * 18}px)` }}>
      <div
        style={{
          display: "inline-block",
          fontFamily: mono,
          fontSize: 13,
          fontWeight: 600,
          letterSpacing: 2,
          textTransform: "uppercase",
          color: "#fff",
          background: color,
          padding: "3px 10px",
          marginBottom: 8,
        }}
      >
        {label}
      </div>
      {children}
    </div>
  );
};

export const PeriodicoRandom: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // seed que cambia lento para que el contenido "random" se sienta vivo pero estable
  const seed = 7;

  const mastP = spring({ frame, fps, config: { damping: 20, stiffness: 80 } });
  const ruleTop = interpolate(frame, [4, 24], [0, 1], { extrapolateRight: "clamp" });
  const ruleBot = interpolate(frame, [10, 34], [0, 1], { extrapolateRight: "clamp" });
  const shieldP = spring({ frame: frame - 4, fps, config: { damping: 14, stiffness: 120 } });

  return (
    <AbsoluteFill
      style={{
        background: C.paper,
        backgroundImage:
          "repeating-linear-gradient(0deg, rgba(20,18,16,.025) 0 1px, transparent 1px 4px)",
        fontFamily: sans,
        color: C.ink,
        padding: 48,
        display: "flex",
        flexDirection: "column",
      }}
    >
      {/* ===== MASTHEAD ===== */}
      <div style={{ opacity: mastP }}>
        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            fontFamily: mono,
            fontSize: 13,
            color: C.inkSoft,
            letterSpacing: 1,
            marginBottom: 6,
          }}
        >
          <span>Vol. VI · Edición del salón</span>
          <span>Precio: 1 chisme</span>
        </div>
        <Rule p={ruleTop} h={5} />
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 20,
            padding: "12px 0 10px",
          }}
        >
          <div
            style={{
              transform: `scale(${0.7 + shieldP * 0.3}) rotate(${(1 - shieldP) * -8}deg)`,
              opacity: shieldP,
              filter: "drop-shadow(0 6px 12px rgba(0,0,0,.2))",
            }}
          >
            <Img src={staticFile("escudo.png")} style={{ width: 96, height: "auto", display: "block" }} />
          </div>
          <div style={{ flex: 1, textAlign: "center" }}>
            <div
              style={{
                fontFamily: serif,
                fontWeight: 900,
                fontSize: 82,
                lineHeight: 0.9,
                letterSpacing: -1,
                color: C.ink,
              }}
            >
              El Panamericano
            </div>
            <div
              style={{
                fontFamily: mono,
                fontSize: 12,
                letterSpacing: 4,
                textTransform: "uppercase",
                color: C.coral,
                marginTop: 6,
              }}
            >
              Diario no oficial del 6º grado · Sin filtro
            </div>
          </div>
          <div style={{ width: 96, textAlign: "right", fontFamily: mono, fontSize: 12, color: C.inkSoft, lineHeight: 1.5 }}>
            HOY<br />★★★<br />Nublado<br />de tareas
          </div>
        </div>
        <Rule p={ruleBot} h={3} />
      </div>

      {/* ===== LEAD ===== */}
      <div style={{ display: "flex", gap: 22, marginTop: 18 }}>
        {/* Columna principal */}
        <div style={{ flex: 1.5, display: "flex", flexDirection: "column", gap: 18, borderRight: `1px solid ${C.inkMute}55`, paddingRight: 22 }}>
          <Section label="Portada" color={C.coral} delay={20}>
            <div style={{ fontFamily: serif, fontWeight: 800, fontSize: 44, lineHeight: 1, letterSpacing: -0.5, marginBottom: 12 }}>
              {rand(LEADS, seed)}
            </div>
            <div
              style={{
                height: 200,
                background: `linear-gradient(135deg, ${C.school}, ${C.coral})`,
                borderRadius: 4,
                marginBottom: 12,
                display: "grid",
                placeItems: "center",
                color: "#ffffffaa",
                fontFamily: mono,
                fontSize: 12,
                letterSpacing: 2,
              }}
            >
              [ FOTO EXCLUSIVA ]
            </div>
            <div style={{ fontSize: 15, lineHeight: 1.5, color: C.inkSoft, columnCount: 2, columnGap: 18 }}>
              {FILLER} {FILLER}
            </div>
          </Section>

          <Section label="Dato del día" color={C.mint} delay={44}>
            <div style={{ fontFamily: serif, fontSize: 19, fontStyle: "italic", color: C.ink, lineHeight: 1.35 }}>
              “{rand(FACTS, seed + 1)}”
            </div>
          </Section>
        </div>

        {/* Sidebar */}
        <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 20 }}>
          <Section label="Chismes" color={C.school} delay={28}>
            <div style={{ fontFamily: serif, fontWeight: 700, fontSize: 22, lineHeight: 1.05, marginBottom: 8 }}>
              Lo que se dice en los pasillos
            </div>
            <div style={{ fontSize: 14, lineHeight: 1.45, color: C.inkSoft, marginBottom: 8 }}>
              {rand(CHISMES, seed)}
            </div>
            <FakeLines n={4} />
          </Section>

          <Section label="Deportes" color={C.coral} delay={36}>
            <div style={{ fontFamily: serif, fontWeight: 700, fontSize: 22, lineHeight: 1.05, marginBottom: 8 }}>
              Liga Lipton
            </div>
            <div style={{ fontSize: 14, lineHeight: 1.45, color: C.inkSoft }}>
              {rand(DEPORTES, seed)}
            </div>
          </Section>

          <Section label="El rincón místico" color={C.lemon} delay={52}>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              <div style={{ background: C.paper2, borderRadius: 6, padding: "10px 12px" }}>
                <div style={{ fontFamily: mono, fontSize: 10, letterSpacing: 1, color: C.inkMute, textTransform: "uppercase" }}>Clima</div>
                <div style={{ fontSize: 14, fontWeight: 600, marginTop: 3 }}>{rand(CLIMAS, seed)}</div>
              </div>
              <div style={{ background: C.paper2, borderRadius: 6, padding: "10px 12px" }}>
                <div style={{ fontFamily: mono, fontSize: 10, letterSpacing: 1, color: C.inkMute, textTransform: "uppercase" }}>Nº de la suerte</div>
                <div style={{ fontFamily: serif, fontSize: 26, fontWeight: 900, color: C.coral, marginTop: 1 }}>{rand(SUERTE, seed)}</div>
              </div>
              <div style={{ gridColumn: "1 / -1", background: C.paper2, borderRadius: 6, padding: "10px 12px" }}>
                <div style={{ fontFamily: mono, fontSize: 10, letterSpacing: 1, color: C.inkMute, textTransform: "uppercase" }}>Horóscopo del salón</div>
                <div style={{ fontSize: 14, marginTop: 3, fontStyle: "italic" }}>{rand(HOROS, seed)}</div>
              </div>
            </div>
          </Section>
        </div>
      </div>

      {/* ===== CLASIFICADOS (a lo ancho) ===== */}
      <div style={{ marginTop: 18 }}>
        <Section label="Clasificados del salón" color={C.mint} delay={58}>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 14 }}>
            {[
              { t: "SE BUSCA", b: "Dueño del suéter azul del perchero. Recompensa: un abrazo." },
              { t: "SE VENDE", b: "Lápiz con historia, prestado 14 veces, nunca devuelto. Barato." },
              { t: "SE OFRECE", b: "Copio la tarea a cambio de pupusa. Seriedad absoluta." },
              { t: "PERDIDO", b: "Balón oficial del lunch. Última vez visto volando por la ventana." },
              { t: "URGENTE", b: "Cargador de vida para el lunes. Preguntar por cualquiera." },
              { t: "AVISO", b: "El aire acondicionado renunció. Traigan abanico de mano." },
            ].map((c, i) => (
              <div key={i} style={{ border: `1px solid ${C.inkMute}55`, borderRadius: 4, padding: "10px 12px", background: C.paper }}>
                <div style={{ fontFamily: mono, fontSize: 10, letterSpacing: 1.5, color: C.coral, fontWeight: 600 }}>{c.t}</div>
                <div style={{ fontSize: 13, lineHeight: 1.35, color: C.inkSoft, marginTop: 4 }}>{c.b}</div>
              </div>
            ))}
          </div>
        </Section>
      </div>

      {/* ===== FOOTER STRIP ===== */}
      <div
        style={{
          marginTop: "auto",
          paddingTop: 12,
          borderTop: `3px solid ${C.rule}`,
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          fontFamily: mono,
          fontSize: 12,
          color: C.inkSoft,
          letterSpacing: 1,
          opacity: spring({ frame: frame - 60, fps, config: { damping: 20 } }),
        }}
      >
        <span>Impreso en el pupitre del fondo</span>
        <span style={{ color: C.coral, fontWeight: 600 }}>★ Toda coincidencia con la realidad es pura casualidad ★</span>
        <span>Continúa en pág. 6</span>
      </div>
    </AbsoluteFill>
  );
};
