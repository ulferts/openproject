// -- copyright
// OpenProject is a project management system.
// Copyright (C) 2012-2018 the OpenProject Foundation (OPF)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See doc/COPYRIGHT.rdoc for more details.
// ++
import {Ng2StateDeclaration, UIRouter} from '@uirouter/angular';
import {IFCViewerPageComponent} from "core-app/modules/ifc_models/pages/viewer/ifc-viewer-page.component";
import {BCFListContainerComponent} from "core-app/modules/ifc_models/bcf/list-container/bcf-list-container.component";
import {IFCViewerComponent} from "core-app/modules/ifc_models/ifc-viewer/ifc-viewer.component";
import {WorkPackagesBaseComponent} from "core-app/modules/work_packages/routing/wp-base/wp--base.component";
import {EmptyComponent} from "core-app/modules/ifc_models/empty/empty-component";
import {WorkPackageNewSplitViewComponent} from "core-components/wp-new/wp-new-split-view.component";
import {BCFNewSplitComponent} from "core-app/modules/ifc_models/bcf/new-split/bcf-new-split.component";
import {BcfSingleViewComponent} from "core-app/modules/ifc_models/bcf/single-view/bcf-single-view.component";
import {WorkPackageOverviewTabComponent} from "core-components/wp-single-view-tabs/overview-tab/overview-tab.component";
import {WorkPackageActivityTabComponent} from "core-components/wp-single-view-tabs/activity-panel/activity-tab.component";
import {WorkPackageRelationsTabComponent} from "core-components/wp-single-view-tabs/relations-tab/relations-tab.component";
import {WorkPackageWatchersTabComponent} from "core-components/wp-single-view-tabs/watchers-tab/watchers-tab.component";

export const IFC_ROUTES:Ng2StateDeclaration[] = [
  {
    name: 'bim',
    parent: 'root',
    url: '/ifc_models',
    abstract: true,
    component: WorkPackagesBaseComponent
  },
  {
    name: 'bim.space',
    url: '',
    abstract: true,
    component: IFCViewerPageComponent
  },
  {
    name: 'bim.space.list',
    url: '/list',
    component: IFCViewerPageComponent,
    views: {
      list: { component: BCFListContainerComponent }
    }
  },
  {
    name: 'bim.space.defaults',
    url: '/defaults',
    component: IFCViewerPageComponent,
    views: {
      viewer: { component: IFCViewerComponent },
      list: { component: BCFListContainerComponent }
    }
  },
  {
    name: 'bim.space.defaults.model',
    url: '/model',
    component: IFCViewerPageComponent,
    views: {
      // Retarget and by that override the grandparent views
      // https://ui-router.github.io/guide/views#relative-parent-state
      'list@^.^': { component: EmptyComponent }
    }
  },
  {
    name: 'bim.space.defaults.single_bcf',
    redirectTo: 'bim.space.defaults.single_bcf.overview',
    url: '/details/{workPackageId:[0-9]+}',
    component: IFCViewerPageComponent,
    reloadOnSearch: false,
    data: {
      bodyClasses: 'router--work-packages-split-view',
    },
    views: {
      viewer: { component: IFCViewerComponent },
      // Retarget and by that override the grandparent views
      // https://ui-router.github.io/guide/views#relative-parent-state
      'list@^.^': { component: BcfSingleViewComponent }
    }
  },
  {
    name: 'bim.space.defaults.single_bcf.overview',
    url: '/overview',
    component: WorkPackageOverviewTabComponent,
    data: {
      parent: 'bim.space.defaults.single_bcf'
    }
  },
  {
    name: 'bim.space.defaults.single_bcf.activity',
    url: '/activity',
    component: WorkPackageActivityTabComponent,
    data: {
      parent: 'bim.space.defaults.single_bcf'
    }
  },
  {
    name: 'bim.space.defaults.single_bcf.activity.details',
    url: '/activity/details/#{activity_no:\d+}',
    component: WorkPackageActivityTabComponent,
    data: {
      parent: 'bim.space.defaults.single_bcf'
    }
  },
  {
    name: 'bim.space.defaults.single_bcf.relations',
    url: '/relations',
    component: WorkPackageRelationsTabComponent,
    data: {
      parent: 'bim.space.defaults.single_bcf'
    }
  },
  {
    name: 'bim.space.defaults.single_bcf.watchers',
    url: '/watchers',
    component: WorkPackageWatchersTabComponent,
    data: {
      parent: 'bim.space.defaults.single_bcf'
    }
  },
  {
    name: 'bim.space.defaults.new',
    url: '/new?{type:[0-9]+}',
    component: IFCViewerPageComponent,
    reloadOnSearch: false,
    views: {
      viewer: { component: IFCViewerComponent },
      // Retarget and by that override the grandparent views
      // https://ui-router.github.io/guide/views#relative-parent-state
      'list@^.^': { component: BCFNewSplitComponent }
    }
  },
  {
    name: 'bim.space.show',
    url: '/{model_id:[0-9]+}',
    component: IFCViewerPageComponent,
    views: {
      viewer: { component: IFCViewerComponent },
      list: { component: BCFListContainerComponent }
    }
  },
  {
    name: 'bim.space.show.model',
    url: '/model',
    component: IFCViewerPageComponent,
    views: {
      // Retarget and by that override the grandparent views
      // https://ui-router.github.io/guide/views#relative-parent-state
      'list@^.^': { component: EmptyComponent }
    }
  },
];
