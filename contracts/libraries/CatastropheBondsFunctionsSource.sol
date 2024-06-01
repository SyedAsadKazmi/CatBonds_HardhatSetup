// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library FunctionsSource {
    function getCatBondsApiInteractionScript()
        internal
        pure
        returns (string memory)
    {
        return
            "const catastropheCode = args[0];"
            "const location = args[1];"
            "const startDate_Timestamp = args[2];"
            "const endDate_Timestamp = args[3];"
            "const apiResponse = await Functions.makeHttpRequest({"
            "    url: 'https://europe-west3-shamba-staging-environment.cloudfunctions.net/cat-bonds-api-test/sendRequestToShambaOracle',"
            "    method: 'POST',"
            "    timeout: 9000,"
            "    headers: {"
            "        'SECRET': secrets.SECRET,"
            "    },"
            "    data: {"
            "        'catastropheCode': catastropheCode,"
            "        'location': location,"
            "        'startDate_Timestamp': startDate_Timestamp,"
            "        'endDate_Timestamp': endDate_Timestamp"
            "    }"
            "});"
            "if (apiResponse.error) {"
            "    throw Error('Request failed');"
            "}"
            "const { data } = apiResponse;"
            "return Functions.encodeUint256(data.data.settleToEnumPosition);";
    }
}
