import useSWRInfinite from "swr/infinite";
import wretch from "wretch";

export type Current = {
  head: string;
  last: string | null;
  updated_at: number;
};

export type PageId = string;
export type Batch = {
  id: string;
  head: boolean;
  pages: PageId[];
  next: string | null;
  created_at: number;
  updated_at: number;
  updated_nonce?: string;
};

export type Page = {
  id: string;
  statuses: PageStatusItem[];
  created_at?: number;
  virtual?: true;
};

export type PageStatusItem = {
  id: string;
  ts?: number;
};

export async function fetchCurrent(): Promise<Current> {
  return await wretch(`${import.meta.env.VITE_DATA_URL}/current.json`)
    .get()
    .json();
}

export async function fetchBatch(batchId: string): Promise<Batch> {
  return await wretch(
    `${import.meta.env.VITE_DATA_URL}/batches/${batchId}.json`
  )
    .get()
    .json();
}

const HEAD_PAGE_PATTERN = /^head\/[^/]+\/([0-9]+)$/;
export async function fetchPage(pageId: PageId): Promise<Page> {
  const m = pageId.match(HEAD_PAGE_PATTERN);
  if (m && m[1]) {
    return {
      id: pageId,
      statuses: [{ id: m[1] }],
      virtual: true,
    };
  }

  return await wretch(`${import.meta.env.VITE_DATA_URL}/pages/${pageId}.json`)
    .get()
    .json();
}

export async function fetchFirstPageOrMakeVirtual(
  batch: Batch
): Promise<PageFetcherResponse> {
  // Return head batch as a single virtual page
  if (batch.head) {
    return {
      batch: { ...batch, pages: [`head-virtual/${batch.id}`] },
      page: await singleVirtualPage(batch),
    };
  }
  return {
    batch,
    page: await fetchPage(batch.pages[0]),
  };
}

export type PageFetcherResponse =
  | { batch: Batch; page: Page }
  | { batch: null; empty: true };
export type PageFetcherKey = ["publikes-swr", string | null, PageId | null];

async function loadFirstPage(
  startBatch: string | null
): Promise<[Batch, Current | undefined]> {
  if (startBatch) {
    return [await fetchBatch(startBatch), undefined];
  } else {
    const current = await fetchCurrent();
    return [await fetchBatch(current.head), current];
  }
}

function getPageKey(
  startBatch: string | undefined,
  index: number,
  previousPageData?: PageFetcherResponse
): PageFetcherKey | null {
  if (index === 0) {
    // Load first page and first batch
    return ["publikes-swr", startBatch || null, null];
  }
  if (previousPageData?.batch?.head) {
    // Head is emulated as a single page, force load next batch
    return ["publikes-swr", previousPageData.batch.next || "@LAST", null];
  }
  if (previousPageData?.batch) {
    // Load next page in the same batch
    const idx = previousPageData.batch.pages.indexOf(previousPageData.page.id);
    if (idx >= 0 && previousPageData.batch.pages[idx + 1]) {
      return [
        "publikes-swr",
        previousPageData.batch.id,
        previousPageData.batch.pages[idx + 1],
      ];
    }
  }
  if (previousPageData?.batch?.next) {
    return ["publikes-swr", previousPageData?.batch?.next, null];
  }
  return null;
}

async function pageFetcher(key: PageFetcherKey): Promise<PageFetcherResponse> {
  const [, batchKey, pageKey] = key;
  console.log("pageFetcher > batchKey/pageKey", batchKey, pageKey);
  if (!batchKey) {
    // Load first page and first batch
    const [batch, maybeCurrent] = await loadFirstPage(batchKey);

    if (batch.pages[0]) {
      console.log("loadFirstPage > fetchFirstPageOrMakeVirtual", batch.pages);
      return await fetchFirstPageOrMakeVirtual(batch);
    } else if (batch.head && !batch.next) {
      console.log("loadFirstPage > empty head", batch.pages);
      const current = maybeCurrent ?? (await fetchCurrent());
      if (current.last)
        return pageFetcher(["publikes-swr", current.last, null]);
    } else if (batch.next) {
      return pageFetcher(["publikes-swr", batch.next, null]);
    }

    console.warn("Possibly empty");
    return { batch: null, empty: true };
  }

  if (batchKey && pageKey) {
    // Load next page in the same batch
    return {
      batch: await fetchBatch(batchKey),
      page: await fetchPage(pageKey),
    };
  }
  if (batchKey) {
    // Load next batch and its first page
    const batchId =
      batchKey == "@LAST" ? (await fetchCurrent()).last : batchKey;
    if (!batchId) return { batch: null, empty: true };

    let batch = await fetchBatch(batchId);
    while (batch.pages.length < 1 && batch.next) {
      batch = await fetchBatch(batch?.next);
    }

    if (batch.pages[0]) {
      return await fetchFirstPageOrMakeVirtual(batch);
    }
  }

  console.warn("Last Resort Empty");
  return { batch: null, empty: true };
}

async function singleVirtualPage(batch: Batch): Promise<Page> {
  console.log("singleVirtualPage", batch);
  return {
    id: `head-virtual/${batch.id}`,
    virtual: true,
    statuses: (await Promise.all(batch.pages.map((p) => fetchPage(p)))).flatMap(
      (p) => p.statuses
    ),
  };
}

export function usePageInfinite(startBatch?: string) {
  return useSWRInfinite(
    (index, previousPageData) => {
      const retval = getPageKey(startBatch, index, previousPageData);
      console.log("pageKey", { startBatch, index, previousPageData }, retval);
      return retval;
    },
    pageFetcher,
    {
      initialSize: 1,
      revalidateIfStale: false,
      revalidateOnMount: true,
      revalidateOnReconnect: false,
      revalidateFirstPage: false,
    }
  );
}
