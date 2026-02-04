import { useState } from 'react';
import { Explore } from './pages/Explore';
import { Home } from './pages/Home';

export const AppSkeleton = () => {
  const [activeTab, setActiveTab] = useState<'home' | 'explore'>('home');

  return (
    <div className="drawer lg:drawer-open">
      <input id="my-drawer" type="checkbox" className="drawer-toggle" />
      <div className="drawer-content flex flex-col items-center justify-center">
        <nav className="lg:hidden navbar w-full bg-base-100">
          <div className="flex-none lg:hidden">
            <label
              htmlFor="my-drawer"
              className="drawer-button btn btn-square btn-ghost"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                className="inline-block h-5 w-5 stroke-current"
              >
                {' '}
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  d="M4 6h16M4 12h16M4 18h16"
                ></path>{' '}
              </svg>
            </label>
          </div>
        </nav>
        <div className="p-10 h-full w-full flex flex-col items-center justify-start">
          <div className="w-full">
            {activeTab === 'home' && <Home />}
            {activeTab === 'explore' && <Explore />}
          </div>
        </div>
      </div>
      <div className="drawer-side">
        <label
          htmlFor="my-drawer"
          aria-label="close sidebar"
          className="drawer-overlay"
        ></label>
        <ul className="menu bg-base-200 min-h-full w-60 p-4">
          <li onClick={() => setActiveTab('home')}>
            <a className="flex flex-row items-center gap-2">
              <div>🏠</div>
              <div>Home</div>
            </a>
          </li>
          <li onClick={() => setActiveTab('explore')}>
            <a className="flex flex-row items-center gap-2">
              <div>🆕</div>
              <div>Explore</div>
            </a>
          </li>
        </ul>
      </div>
    </div>
  );
};
