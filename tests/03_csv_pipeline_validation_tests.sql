/*==============================================================================
  Snowflake Certification Enablement Platform
  CSV Pipeline Validation Tests

  Purpose:
  - Validate learner ingestion.
  - Validate learning-path assignment.
  - Validate progress ingestion.
  - Validate rejected-record handling.
  - Validate duplicate prevention.
  - Validate final learner progress.
==============================================================================*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE SNOWPRO_LEARNING_WH;
USE DATABASE SNOWPRO_ENABLEMENT;


/*------------------------------------------------------------------------------
  Execute all validation tests
------------------------------------------------------------------------------*/

WITH TEST_RESULTS AS
(

    /* Test 1: All three demo learners exist. */

    SELECT
        'TC-001' AS TEST_ID,
        'Three demo learners were registered' AS TEST_DESCRIPTION,
        '3' AS EXPECTED_RESULT,

        TO_VARCHAR(
            (
                SELECT COUNT(*)

                FROM CORE.LEARNERS

                WHERE EMPLOYEE_ID IN
                (
                    'EMP_DEMO_001',
                    'EMP_DEMO_002',
                    'EMP_DEMO_003'
                )
            )
        ) AS ACTUAL_RESULT,

        IFF(
            (
                SELECT COUNT(*)

                FROM CORE.LEARNERS

                WHERE EMPLOYEE_ID IN
                (
                    'EMP_DEMO_001',
                    'EMP_DEMO_002',
                    'EMP_DEMO_003'
                )
            ) = 3,
            'PASS',
            'FAIL'
        ) AS TEST_STATUS


    UNION ALL


    /* Test 2: Each demo learner has an active enrollment. */

    SELECT
        'TC-002',
        'Each demo learner has an active enrollment',
        '3',

        TO_VARCHAR(
            (
                SELECT COUNT(*)

                FROM CORE.LEARNERS L

                JOIN CORE.ENROLLMENTS E
                    ON L.LEARNER_ID = E.LEARNER_ID

                WHERE L.EMPLOYEE_ID IN
                (
                    'EMP_DEMO_001',
                    'EMP_DEMO_002',
                    'EMP_DEMO_003'
                )

                AND E.ENROLLMENT_STATUS = 'ACTIVE'
            )
        ),

        IFF(
            (
                SELECT COUNT(*)

                FROM CORE.LEARNERS L

                JOIN CORE.ENROLLMENTS E
                    ON L.LEARNER_ID = E.LEARNER_ID

                WHERE L.EMPLOYEE_ID IN
                (
                    'EMP_DEMO_001',
                    'EMP_DEMO_002',
                    'EMP_DEMO_003'
                )

                AND E.ENROLLMENT_STATUS = 'ACTIVE'
            ) = 3,
            'PASS',
            'FAIL'
        )


    UNION ALL


    /* Test 3: Correct learning paths were assigned. */

    SELECT
        'TC-003',
        'Experience-based learning paths were assigned correctly',
        '3 correct path assignments',

        TO_VARCHAR(
            (
                SELECT COUNT(*)

                FROM CORE.LEARNERS L

                JOIN CORE.ENROLLMENTS E
                    ON L.LEARNER_ID = E.LEARNER_ID

                WHERE
                    (
                        L.EMPLOYEE_ID = 'EMP_DEMO_001'
                        AND E.PATH_ID = 'PATH_FRESHER'
                    )

                    OR
                    (
                        L.EMPLOYEE_ID = 'EMP_DEMO_002'
                        AND E.PATH_ID = 'PATH_0_5'
                    )

                    OR
                    (
                        L.EMPLOYEE_ID = 'EMP_DEMO_003'
                        AND E.PATH_ID = 'PATH_0_5'
                    )
            )
        ) || ' correct path assignments',

        IFF(
            (
                SELECT COUNT(*)

                FROM CORE.LEARNERS L

                JOIN CORE.ENROLLMENTS E
                    ON L.LEARNER_ID = E.LEARNER_ID

                WHERE
                    (
                        L.EMPLOYEE_ID = 'EMP_DEMO_001'
                        AND E.PATH_ID = 'PATH_FRESHER'
                    )

                    OR
                    (
                        L.EMPLOYEE_ID = 'EMP_DEMO_002'
                        AND E.PATH_ID = 'PATH_0_5'
                    )

                    OR
                    (
                        L.EMPLOYEE_ID = 'EMP_DEMO_003'
                        AND E.PATH_ID = 'PATH_0_5'
                    )
            ) = 3,
            'PASS',
            'FAIL'
        )


    UNION ALL


    /* Test 4: Each demo learner has 31 assigned topics. */

    SELECT
        'TC-004',
        'Each demo learner has 31 initialized topics',
        '3 learners with 31 topics',

        TO_VARCHAR(
            (
                SELECT COUNT(*)

                FROM
                (
                    SELECT
                        L.EMPLOYEE_ID,
                        COUNT(TP.TOPIC_ID) AS TOPIC_COUNT

                    FROM CORE.LEARNERS L

                    JOIN CORE.ENROLLMENTS E
                        ON L.LEARNER_ID = E.LEARNER_ID

                    JOIN CORE.TOPIC_PROGRESS TP
                        ON E.ENROLLMENT_ID = TP.ENROLLMENT_ID

                    WHERE L.EMPLOYEE_ID IN
                    (
                        'EMP_DEMO_001',
                        'EMP_DEMO_002',
                        'EMP_DEMO_003'
                    )

                    GROUP BY L.EMPLOYEE_ID

                    HAVING COUNT(TP.TOPIC_ID) = 31
                )
            )
        ) || ' learners with 31 topics',

        IFF(
            (
                SELECT COUNT(*)

                FROM
                (
                    SELECT
                        L.EMPLOYEE_ID,
                        COUNT(TP.TOPIC_ID) AS TOPIC_COUNT

                    FROM CORE.LEARNERS L

                    JOIN CORE.ENROLLMENTS E
                        ON L.LEARNER_ID = E.LEARNER_ID

                    JOIN CORE.TOPIC_PROGRESS TP
                        ON E.ENROLLMENT_ID = TP.ENROLLMENT_ID

                    WHERE L.EMPLOYEE_ID IN
                    (
                        'EMP_DEMO_001',
                        'EMP_DEMO_002',
                        'EMP_DEMO_003'
                    )

                    GROUP BY L.EMPLOYEE_ID

                    HAVING COUNT(TP.TOPIC_ID) = 31
                )
            ) = 3,
            'PASS',
            'FAIL'
        )


    UNION ALL


    /* Test 5: Three learner source records were processed successfully. */

    SELECT
        'TC-005',
        'Learner source records were processed successfully',
        '3',

        TO_VARCHAR(
            (
                SELECT COUNT(*)

                FROM CONTROL.CSV_PROCESSED_RECORDS

                WHERE PIPELINE_NAME = 'LEARNER_INFORMATION'

                  AND SOURCE_RECORD_ID IN
                  (
                      'LRN_REC_001',
                      'LRN_REC_002',
                      'LRN_BAD_001'
                  )
            )
        ),

        IFF(
            (
                SELECT COUNT(*)

                FROM CONTROL.CSV_PROCESSED_RECORDS

                WHERE PIPELINE_NAME = 'LEARNER_INFORMATION'

                  AND SOURCE_RECORD_ID IN
                  (
                      'LRN_REC_001',
                      'LRN_REC_002',
                      'LRN_BAD_001'
                  )
            ) = 3,
            'PASS',
            'FAIL'
        )


    UNION ALL


    /* Test 6: Three progress source records were processed successfully. */

    SELECT
        'TC-006',
        'Progress source records were processed successfully',
        '3',

        TO_VARCHAR(
            (
                SELECT COUNT(*)

                FROM CONTROL.CSV_PROCESSED_RECORDS

                WHERE PIPELINE_NAME = 'LEARNER_PROGRESS'

                  AND SOURCE_RECORD_ID IN
                  (
                      'ACT_DEMO_001',
                      'ACT_DEMO_002',
                      'ACT_BAD_001'
                  )
            )
        ),

        IFF(
            (
                SELECT COUNT(*)

                FROM CONTROL.CSV_PROCESSED_RECORDS

                WHERE PIPELINE_NAME = 'LEARNER_PROGRESS'

                  AND SOURCE_RECORD_ID IN
                  (
                      'ACT_DEMO_001',
                      'ACT_DEMO_002',
                      'ACT_BAD_001'
                  )
            ) = 3,
            'PASS',
            'FAIL'
        )


    UNION ALL


    /* Test 7: Both intentional invalid records were rejected. */

    SELECT
        'TC-007',
        'Intentional invalid records were rejected',
        '2',

        TO_VARCHAR(
            (
                SELECT COUNT(*)

                FROM CONTROL.CSV_REJECTED_RECORDS

                WHERE SOURCE_RECORD_ID IN
                (
                    'LRN_BAD_001',
                    'ACT_BAD_001'
                )
            )
        ),

        IFF(
            (
                SELECT COUNT(*)

                FROM CONTROL.CSV_REJECTED_RECORDS

                WHERE SOURCE_RECORD_ID IN
                (
                    'LRN_BAD_001',
                    'ACT_BAD_001'
                )
            ) = 2,
            'PASS',
            'FAIL'
        )


    UNION ALL


    /* Test 8: Both corrected rejections are marked resolved. */

    SELECT
        'TC-008',
        'Corrected rejected records are marked resolved',
        '2',

        TO_VARCHAR(
            (
                SELECT COUNT(*)

                FROM CONTROL.CSV_REJECTED_RECORDS

                WHERE SOURCE_RECORD_ID IN
                (
                    'LRN_BAD_001',
                    'ACT_BAD_001'
                )

                AND RESOLVED_FLAG = TRUE
            )
        ),

        IFF(
            (
                SELECT COUNT(*)

                FROM CONTROL.CSV_REJECTED_RECORDS

                WHERE SOURCE_RECORD_ID IN
                (
                    'LRN_BAD_001',
                    'ACT_BAD_001'
                )

                AND RESOLVED_FLAG = TRUE
            ) = 2,
            'PASS',
            'FAIL'
        )


    UNION ALL


    /* Test 9: No duplicate demo learners exist. */

    SELECT
        'TC-009',
        'No duplicate demo employee IDs exist',
        '0 duplicate employee IDs',

        TO_VARCHAR(
            (
                SELECT COUNT(*)

                FROM
                (
                    SELECT EMPLOYEE_ID

                    FROM CORE.LEARNERS

                    WHERE EMPLOYEE_ID IN
                    (
                        'EMP_DEMO_001',
                        'EMP_DEMO_002',
                        'EMP_DEMO_003'
                    )

                    GROUP BY EMPLOYEE_ID

                    HAVING COUNT(*) > 1
                )
            )
        ) || ' duplicate employee IDs',

        IFF(
            (
                SELECT COUNT(*)

                FROM
                (
                    SELECT EMPLOYEE_ID

                    FROM CORE.LEARNERS

                    WHERE EMPLOYEE_ID IN
                    (
                        'EMP_DEMO_001',
                        'EMP_DEMO_002',
                        'EMP_DEMO_003'
                    )

                    GROUP BY EMPLOYEE_ID

                    HAVING COUNT(*) > 1
                )
            ) = 0,
            'PASS',
            'FAIL'
        )


    UNION ALL


    /* Test 10: No duplicate demo activity IDs exist. */

    SELECT
        'TC-010',
        'No duplicate demo activity IDs exist',
        '0 duplicate activity IDs',

        TO_VARCHAR(
            (
                SELECT COUNT(*)

                FROM
                (
                    SELECT EVENT_ID

                    FROM CORE.LEARNING_EVENTS

                    WHERE EVENT_ID IN
                    (
                        'ACT_DEMO_001',
                        'ACT_DEMO_002',
                        'ACT_BAD_001'
                    )

                    GROUP BY EVENT_ID

                    HAVING COUNT(*) > 1
                )
            )
        ) || ' duplicate activity IDs',

        IFF(
            (
                SELECT COUNT(*)

                FROM
                (
                    SELECT EVENT_ID

                    FROM CORE.LEARNING_EVENTS

                    WHERE EVENT_ID IN
                    (
                        'ACT_DEMO_001',
                        'ACT_DEMO_002',
                        'ACT_BAD_001'
                    )

                    GROUP BY EVENT_ID

                    HAVING COUNT(*) > 1
                )
            ) = 0,
            'PASS',
            'FAIL'
        )


    UNION ALL


    /* Test 11: First learner reached completed status after correction. */

    SELECT
        'TC-011',
        'Corrected progress completed EMP_DEMO_001 topic D01_T01',
        'COMPLETED / 100 / 1.00 hours',

        COALESCE(
            (
                SELECT
                    TP.PROGRESS_STATUS ||
                    ' / ' ||
                    TO_VARCHAR(TP.COMPLETION_PERCENT) ||
                    ' / ' ||
                    TO_VARCHAR(TP.HOURS_SPENT) ||
                    ' hours'

                FROM CORE.LEARNERS L

                JOIN CORE.ENROLLMENTS E
                    ON L.LEARNER_ID = E.LEARNER_ID

                JOIN CORE.TOPIC_PROGRESS TP
                    ON E.ENROLLMENT_ID = TP.ENROLLMENT_ID

                WHERE L.EMPLOYEE_ID = 'EMP_DEMO_001'
                  AND TP.TOPIC_ID = 'D01_T01'
            ),
            'No result'
        ),

        IFF(
            (
                SELECT COUNT(*)

                FROM CORE.LEARNERS L

                JOIN CORE.ENROLLMENTS E
                    ON L.LEARNER_ID = E.LEARNER_ID

                JOIN CORE.TOPIC_PROGRESS TP
                    ON E.ENROLLMENT_ID = TP.ENROLLMENT_ID

                WHERE L.EMPLOYEE_ID = 'EMP_DEMO_001'
                  AND TP.TOPIC_ID = 'D01_T01'
                  AND TP.PROGRESS_STATUS = 'COMPLETED'
                  AND TP.COMPLETION_PERCENT = 100
                  AND ROUND(TP.HOURS_SPENT, 2) = 1.00
            ) = 1,
            'PASS',
            'FAIL'
        )


    UNION ALL


    /* Test 12: Second learner completed the topic. */

    SELECT
        'TC-012',
        'EMP_DEMO_002 completed topic D01_T01',
        'COMPLETED / 100 / 1.25 hours',

        COALESCE(
            (
                SELECT
                    TP.PROGRESS_STATUS ||
                    ' / ' ||
                    TO_VARCHAR(TP.COMPLETION_PERCENT) ||
                    ' / ' ||
                    TO_VARCHAR(TP.HOURS_SPENT) ||
                    ' hours'

                FROM CORE.LEARNERS L

                JOIN CORE.ENROLLMENTS E
                    ON L.LEARNER_ID = E.LEARNER_ID

                JOIN CORE.TOPIC_PROGRESS TP
                    ON E.ENROLLMENT_ID = TP.ENROLLMENT_ID

                WHERE L.EMPLOYEE_ID = 'EMP_DEMO_002'
                  AND TP.TOPIC_ID = 'D01_T01'
            ),
            'No result'
        ),

        IFF(
            (
                SELECT COUNT(*)

                FROM CORE.LEARNERS L

                JOIN CORE.ENROLLMENTS E
                    ON L.LEARNER_ID = E.LEARNER_ID

                JOIN CORE.TOPIC_PROGRESS TP
                    ON E.ENROLLMENT_ID = TP.ENROLLMENT_ID

                WHERE L.EMPLOYEE_ID = 'EMP_DEMO_002'
                  AND TP.TOPIC_ID = 'D01_T01'
                  AND TP.PROGRESS_STATUS = 'COMPLETED'
                  AND TP.COMPLETION_PERCENT = 100
                  AND ROUND(TP.HOURS_SPENT, 2) = 1.25
            ) = 1,
            'PASS',
            'FAIL'
        )

)

SELECT
    TEST_ID,
    TEST_DESCRIPTION,
    EXPECTED_RESULT,
    ACTUAL_RESULT,
    TEST_STATUS

FROM TEST_RESULTS

ORDER BY TEST_ID;