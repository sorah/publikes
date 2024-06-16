import { useCallback, useEffect, useMemo, useRef } from "react";
import { usePageInfinite } from "./Api";
import "./App.css";
import { Tweet } from "react-tweet";

function App() {
  const startBatch = useMemo(() => {
    const search = new URLSearchParams(location.search);
    return search.get("batch") || undefined;
  }, []);
  const { data, error, isLoading, isValidating, size, setSize } =
    usePageInfinite(startBatch);

  const observer = useInteractionObserver(
    useCallback(
      (entries) => {
        if (isValidating || isLoading) return;
        entries.forEach((entry) => {
          if (entry.isIntersecting) setSize(size + 1);
        });
      },
      [isValidating, isLoading, size, setSize]
    ),
    {}
  );

  useEffect(() => {
    if (!data) return;
    if (size < 2) return;
    const batchId = data[data.length - 1]?.batch?.id;
    if (batchId) {
      history.replaceState(
        {},
        "",
        `${location.pathname}?batch=${encodeURIComponent(batchId)}`
      );
    }
  }, [size, data]);

  const lastPage = data ? data[data.length - 1] : undefined;
  const reachedLastPage =
    !isLoading &&
    !isValidating &&
    lastPage &&
    (lastPage.batch ? !lastPage.batch.head && !lastPage.batch.next : true);

  useEffect(() => {}, []);

  return (
    <>
      <header>
        <h1>{import.meta.env.VITE_HTML_TITLE}</h1>
        <p className="powered-by">
          Powered by{" "}
          <a href="https://github.com/sorah/publikes">sorah/publikes</a>
        </p>
      </header>
      {startBatch ? (
        <p className="past-page-warning">
          Browsing the past page ({startBatch}).
          <br />
          <a href="/">Back to the most recent like</a>
        </p>
      ) : null}
      <main>
        {data?.map((b) => {
          if (!b.batch) return null;
          const page = b.page;
          return (
            <div key={`${b.batch.id}-${page.id}`}>
              {page.statuses.map((status) => {
                return (
                  <div
                    key={`${page.id}-${status.id}`}
                    className="liked-tweet"
                    data-status-id={status.id}
                  >
                    <Tweet id={status.id} />
                  </div>
                );
              })}
            </div>
          );
        })}
      </main>
      {error ? <p>Error: {error}</p> : null}
      <div className="load-more" ref={observer}>
        {reachedLastPage ? (
          <p className="last-page">You've reached the last page.</p>
        ) : null}
        {isLoading || isValidating ? <p>👊</p> : null}
      </div>
    </>
  );
}

function useInteractionObserver(
  callback: IntersectionObserverCallback,
  options: IntersectionObserverInit
) {
  const ref = useRef(null);
  const observer = useMemo(
    () => new IntersectionObserver(callback, options),
    [callback, options]
  );
  useEffect(() => {
    const elem = ref.current;
    if (!elem) return;
    observer.observe(elem);
    return () => observer.unobserve(elem);
  }, [observer, ref]);
  return ref;
}

export default App;
