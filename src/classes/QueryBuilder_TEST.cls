/**
    Copyright (c) 2019, Salesforce.org
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
**/
@IsTest(IsParallel=true)
private class QueryBuilder_TEST {
    private static QueryBuilder queryBuilder = new QueryBuilder(Account.SObjectType);
    private static final Integer NUMBER_OF_ACCOUNTS = 2;

    @TestSetup
    private static void makeData() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Find Me', Type = 'Prospect'),
            new Account(Name = 'Hide Me', Type = 'Customer')
        };

        insert accounts;
    }

    @IsTest
    private static void countQueryShouldIncludeWhereClauseWhenConditionProvided() {
        String expectedCountQuery = 'SELECT COUNT() FROM Account WHERE Type = \'Prospect\'';
        String actualCountQuery = queryBuilder.withCondition('Type = \'Prospect\'').buildCount();
        System.assertEquals(
            expectedCountQuery,
            actualCountQuery,
            'Expected the where clause to be part of the count query.'
        );
        System.assertEquals(1, Database.countQuery(actualCountQuery), 'Expected one account to be found.');
    }

    @IsTest
    private static void countQueryShouldNotIncludeWhereClause() {
        String expectedCountQuery = 'SELECT COUNT() FROM Account';
        String actualCountQuery = queryBuilder.buildCount();
        System.assertEquals(
            expectedCountQuery,
            actualCountQuery,
            'Expected count query to be returned without a WHERE clause.'
        );
        System.assertEquals(
            NUMBER_OF_ACCOUNTS,
            Database.countQuery(actualCountQuery),
            'Expected all accounts to be found.'
        );
    }
}