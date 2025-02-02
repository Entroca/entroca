import { Socket } from "net";
import xxhash from "xxhash-wasm";

const { h64 } = await xxhash();

const ERRORS = [
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

const createClient = async (url: string, port: number, thread_count: number) => {
	const sockets: Socket[] = [...new Array(thread_count)];	
	const queues: ((data: any) => void)[][] = [...new Array(thread_count)];

	for (let i = 0; i < thread_count; ++i) {
		await (new Promise((resolve) => {
			const socket = new Socket();

			socket.connect(port + i, url, () => {
				resolve(true);
				console.log('Connected');
			});

			socket.on('data', (data: any) => {
				console.log('Received: ' + data);
				queues[i].shift()?.(data);
			});

			sockets[i] = socket;
			queues[i] = [];
		}));
	}

	return {
		get: (key: Uint8Array): Promise<{ data: Buffer, err: null } | { data: null, err: string }> => {
			const hash = h64(key.toString());
			const index = Number(hash % BigInt(thread_count));
			const socket = sockets[index];	
			const queue = queues[index];

			const key_length = key.length;

			const buffer = new Uint8Array(1 + 8 + key_length);
			const view = new DataView(buffer.buffer);

			view.setUint8(0, 0);
			view.setBigUint64(1, hash);
			buffer.set(key, 9);

			return new Promise((resolve) => {
				queue.push((data: Buffer) => {
					data[0] 
						? resolve({ data: data.slice(1, data.byteLength), err: null })
						: resolve({ data: null, err: ERRORS[data[1]] ?? "UnknownError" });
				});

				socket.write(buffer);
			});
		},
		put: (key: Uint8Array, value: Uint8Array, ttl: number): Promise<{ data: null, err: null } | { data: null, err: string }> => {
			const hash = h64(key.toString());
			const index = Number(hash % BigInt(thread_count));
			const socket = sockets[index];	
			const queue = queues[index];	

			const key_length = key.length;
			const value_length = value.length;

			const buffer = new Uint8Array(1 + 8 + 4 + 4 + key_length + 4 + value_length);
			const view = new DataView(buffer.buffer);

			view.setUint8(0, 1);
			view.setBigUint64(1, hash);
			view.setUint32(9, ttl, true);
			view.setUint32(13, key.length, true);
			buffer.set(key, 17);
			view.setUint32(17 + key_length, value.length, true);
			buffer.set(value, 17 + key_length + 4);

			return new Promise((resolve) => {
				queue.push((data: Buffer) => {
					data[0] 
						? resolve({ data: null, err: null })
						: resolve({ data: null, err: ERRORS[data[1]] ?? "UnknownError" });
				});

				socket.write(buffer);
			});
		},
		del: (key: Uint8Array): Promise<{ data: null, err: null } | { data: null, err: string }> => {
			const hash = h64(key.toString());
			const index = Number(hash % BigInt(thread_count));
			const socket = sockets[index];	
			const queue = queues[index];	

			const key_length = key.length;

			const buffer = new Uint8Array(1 + 8 + key_length);
			const view = new DataView(buffer.buffer);

			view.setUint8(0, 2);
			view.setBigUint64(1, hash);
			buffer.set(key, 9);

			return new Promise((resolve) => {
				queue.push((data: Buffer) => {
					data[0] 
						? resolve({ data: null, err: null })
						: resolve({ data: null, err: ERRORS[data[1]] ?? "UnknownError" });
				});

				socket.write(buffer);
			});
		}
	};
};

const text_encoder = new TextEncoder();

(async () => {
	const client = await createClient("localhost", 3000, 4);

	console.log(await client.put(text_encoder.encode("hello"), text_encoder.encode("world"), 10));
	console.log(await client.get(text_encoder.encode("hello")));
	console.log(await client.del(text_encoder.encode("hello")));
	console.log(await client.get(text_encoder.encode("hello")));
})();

