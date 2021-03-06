import { Injector } from '@angular/core';
import { States } from "core-app/core/states/states.service";
import { WorkPackageTable } from '../../wp-fast-table';
import { commonRowClassName } from '../rows/single-row-builder';
import { WorkPackageViewTimelineService } from "core-app/features/work-packages/routing/wp-view-base/view-services/wp-view-timeline.service";
import { InjectField } from "core-app/shared/helpers/angular/inject-field.decorator";
import { APIV3Service } from "core-app/core/apiv3/api-v3.service";

export const timelineCellClassName = 'wp-timeline-cell';

export class TimelineRowBuilder {

  @InjectField() public states:States;
  @InjectField() public wpTableTimeline:WorkPackageViewTimelineService;

  constructor(public readonly injector:Injector,
              protected workPackageTable:WorkPackageTable) {
  }

  public build(workPackageId:string|null) {
    const cell = document.createElement('div');
    cell.classList.add(timelineCellClassName, commonRowClassName);

    if (workPackageId) {
      cell.dataset['workPackageId'] = workPackageId;
    }

    return cell;
  }

  /**
   * Build and insert a timeline row for the given work package using the additional classes.
   * @param workPackage
   * @param timelineBody
   * @param rowClasses
   */
  public insert(workPackageId:string|null,
    timelineBody:DocumentFragment|HTMLElement,
    rowClasses:string[] = []) {

    const cell = this.build(workPackageId);
    cell.classList.add(...rowClasses);

    timelineBody.appendChild(cell);
  }
}
