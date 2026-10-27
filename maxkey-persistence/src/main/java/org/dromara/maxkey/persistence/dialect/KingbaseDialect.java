/*
 * Copyright [2024] [MaxKey of copyright http://www.maxkey.top]
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 

package org.dromara.maxkey.persistence.dialect;

import org.dromara.mybatis.jpa.dialect.PostgreSQLDialect;

/**
 * KingbaseES 分页方言。
 * <p>
 * KingbaseES 默认兼容 PostgreSQL，分页语法为 LIMIT ? OFFSET ?，
 * 与 {@link PostgreSQLDialect} 一致，故直接继承；如后续出现差异可在此覆写。
 * </p>
 */
public class KingbaseDialect extends PostgreSQLDialect {

    /** mybatis.dialect 配置值 */
    public static final String NAME = "kingbase";

}
