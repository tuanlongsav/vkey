import type React from "react";
import { Composition } from "remotion";
import { vkeyPromo } from "./compositions/vkeyPromo";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="vkeyPromo"
        component={vkeyPromo}
        durationInFrames={700}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
