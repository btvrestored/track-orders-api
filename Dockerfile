FROM denoland/deno:2.5.6

WORKDIR /app

COPY deno.json ./
COPY main.ts ./

# Resolve dependencies during the image build so runtime starts predictably.
RUN deno check main.ts && deno cache main.ts

EXPOSE 10000

CMD ["run", "--cached-only", "--allow-net", "--allow-env", "main.ts"]
