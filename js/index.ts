import { Socket } from "net";
import { cpus } from 'os';
import xxhash from "xxhash-wasm";

const CORE_COUNT = cpus().length;

// Constants and configuration
const COMMAND = {
  GET: 0,
  PUT: 1,
  DELETE: 2,
} as const;

const ERROR_CODES = [
  "KeyTooLong",
  "ValueTooLong",
  "OutOfMemory",
  "RecordEmpty",
  "TtlExpired",
  "RecordNotFound",
  "NotEnoughBytes",
  "NoReturn",
  "CommandNotFound",
];

// Initialize hashing function
const { h64: hashFunction } = await xxhash();

interface ClientResponse<T> {
  data: T;
  err: string | null;
}

const createClient = async (host: string, basePort: number, threadCount: number) => {
  const sockets: Socket[] = new Array(threadCount);
  const responseHandlersQueue: ((data: Buffer) => void)[][] = Array.from({ length: threadCount }, () => []);

  // Connect to all threads concurrently
  await Promise.all(
    Array.from({ length: threadCount }, async (_, index) => {
      const socket = new Socket();
      const port = basePort + index;

      await new Promise<void>((resolve) => {
        socket.connect(port, host, () => {
          console.log(`Connected to thread ${index} on port ${port}`);
          resolve();
        });
      });

      // Setup data handler for this socket
      socket.on('data', (data: Buffer) => {
        console.log(`Received response from thread ${index}:`, data);
        const handler = responseHandlersQueue[index].shift();
        handler?.(data);
      });

      sockets[index] = socket;
    })
  );

  /**
   * Handles response from server and resolves the appropriate promise
   * @param resolve Promise resolution function
   * @param expectsData Whether to expect payload data in successful response
   */
  const createResponseHandler = <T>(
    resolve: (value: ClientResponse<T>) => void,
    expectsData: boolean
  ) => (data: Buffer) => {
    if (data[0]) { // Non-zero indicates success
      resolve({
        data: expectsData ? data.slice(1) : null,
        err: null
      } as ClientResponse<T>);
    } else {
      resolve({
        data: null,
        err: ERROR_CODES[data[1]] ?? "UnknownError"
      });
    }
  };

  /**
   * Selects appropriate thread resources based on key hash
   * @param key Key to hash for thread selection
   */
  const selectThread = (key: Uint8Array) => {
    const hash = hashFunction(key.toString());
    const threadIndex = Number(hash % BigInt(threadCount));
    return {
      socket: sockets[threadIndex],
      queue: responseHandlersQueue[threadIndex]
    };
  };

  return {
    /**
     * Retrieve a value from the store
     * @param key Binary key to retrieve
     */
    async get(key: Uint8Array): Promise<ClientResponse<Buffer>> {
      const { socket, queue } = selectThread(key);
      
      // Build command buffer: [1 byte command][8 byte hash][key bytes]
      const buffer = new Uint8Array(1 + 8 + key.length);
      const view = new DataView(buffer.buffer);
      const hash = hashFunction(key.toString());
      
      view.setUint8(0, COMMAND.GET);
      view.setBigUint64(1, hash);
      buffer.set(key, 9);

      return new Promise((resolve) => {
        queue.push(createResponseHandler(resolve, true));
        socket.write(buffer);
      });
    },

    /**
     * Store a value in the cache
     * @param key Binary key to store
     * @param value Binary value to store
     * @param ttl Time-to-live in seconds
     */
    async put(
      key: Uint8Array,
      value: Uint8Array,
      ttl: number
    ): Promise<ClientResponse<null>> {
      const { socket, queue } = selectThread(key);
      
      // Calculate buffer layout
      const keyLength = key.length;
      const valueLength = value.length;
      const buffer = new Uint8Array(1 + 8 + 4 + 4 + keyLength + 4 + valueLength);
      const view = new DataView(buffer.buffer);
      const hash = hashFunction(key.toString());

      // Build command buffer:
      // [1 byte command][8 byte hash][4 byte TTL][4 byte key length][key bytes][4 byte value length][value bytes]
      let offset = 0;
      view.setUint8(offset++, COMMAND.PUT);
      view.setBigUint64(offset, hash);
      offset += 8;
      view.setUint32(offset, ttl, true);
      offset += 4;
      view.setUint32(offset, keyLength, true);
      offset += 4;
      buffer.set(key, offset);
      offset += keyLength;
      view.setUint32(offset, valueLength, true);
      offset += 4;
      buffer.set(value, offset);

      return new Promise((resolve) => {
        queue.push(createResponseHandler(resolve, false));
        socket.write(buffer);
      });
    },

    /**
     * Delete a value from the store
     * @param key Binary key to delete
     */
    async del(key: Uint8Array): Promise<ClientResponse<null>> {
      const { socket, queue } = selectThread(key);
      
      // Build command buffer: [1 byte command][8 byte hash][key bytes]
      const buffer = new Uint8Array(1 + 8 + key.length);
      const view = new DataView(buffer.buffer);
      const hash = hashFunction(key.toString());

      view.setUint8(0, COMMAND.DELETE);
      view.setBigUint64(1, hash);
      buffer.set(key, 9);

      return new Promise((resolve) => {
        queue.push(createResponseHandler(resolve, false));
        socket.write(buffer);
      });
    }
  };
};

// Demo usage
const textEncoder = new TextEncoder();

(async () => {
  const client = await createClient("localhost", 3000, CORE_COUNT);

  console.log("Put result:", await client.put(
    textEncoder.encode("hello"),
    textEncoder.encode("world"),
    10
  ));

  console.log("Get result:", await client.get(textEncoder.encode("hello")));
  console.log("Delete result:", await client.del(textEncoder.encode("hello")));
  console.log("Get after delete:", await client.get(textEncoder.encode("hello")));
})();
