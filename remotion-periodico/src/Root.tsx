import { Composition } from "remotion";
import { PeriodicoAnuncio } from "./PeriodicoAnuncio";

export const Root: React.FC = () => {
  return (
    <Composition
      id="PeriodicoAnuncio"
      component={PeriodicoAnuncio}
      durationInFrames={300}
      fps={30}
      width={1080}
      height={1350}
    />
  );
};
